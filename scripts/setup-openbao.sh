#!/usr/bin/env bash
# =============================================================================
# setup-openbao.sh — Install and configure OpenBao for Precision-MOD
#
# Sets up OpenBao as the default credential manager with:
#   - Encrypted file-based storage in .openbao/data/ (safe to commit)
#   - Master keys in ~/.openbao/ (NEVER committed)
#   - Localhost-only listener on 127.0.0.1:8200
#
# Usage: ./setup-openbao.sh [--help] [--dry-run]
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Resolve REPO_ROOT: when this script is run from inside the precision-mod
# clone (submodule or vendored), target the parent project, not the clone.
__sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__ud="$(dirname "$__sd")"
REPO_ROOT="$(git -C "$__ud" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  __parent="$(dirname "$__ud")"
  __ptop="$(git -C "$__parent" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$__ptop" ] && [ "$__ptop" != "$__ud" ]; then
    REPO_ROOT="$__ptop"
  fi
fi
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
unset __sd __ud __parent __ptop
REPO_OPENBAO_DIR="${REPO_ROOT}/.openbao"
HOME_OPENBAO_DIR="${HOME}/.openbao"
BAO_ADDR="http://127.0.0.1:8200"
KV_MOUNT="secret"

DRY_RUN=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf "[INFO]  %s\n" "$*"; }
warn()  { printf "[WARN]  %s\n" "$*" >&2; }
error() { printf "[ERROR] %s\n" "$*" >&2; exit 1; }
step()  { printf "\n==> %s\n" "$*"; }

run() {
    if $DRY_RUN; then
        printf "[DRY-RUN] %s\n" "$*"
    else
        "$@"
    fi
}

usage() {
    cat <<'USAGE'
setup-openbao.sh — Install and configure OpenBao for Precision-MOD

Usage:
    ./setup-openbao.sh [OPTIONS]

Options:
    --help      Show this help message and exit
    --dry-run   Show what would be done without making changes

Description:
    This script performs the following steps:
      1. Detects the OS and installs OpenBao if not present
      2. Creates the repo-side directory structure (.openbao/)
      3. Generates config.hcl (file storage backend, localhost listener)
      4. Creates ~/.openbao/ with start script and init keys
      5. Initializes the vault (single key share)
      6. Unseals and creates the KV v2 secret engine
      7. Ensures .openbao/ is tracked in git and ~/.openbao/ is not

    After setup, source ~/.openbao/start.sh or run it to start the vault.

USAGE
    exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --help)    usage ;;
        --dry-run) DRY_RUN=true ;;
        *)         error "Unknown option: $arg. Use --help for usage." ;;
    esac
done

# ---------------------------------------------------------------------------
# Step 1: Detect OS and install OpenBao
# ---------------------------------------------------------------------------
step "Detecting operating system"

OS="$(uname -s)"
case "$OS" in
    Darwin)
        info "macOS detected"
        INSTALL_CMD="brew"
        ;;
    Linux)
        info "Linux detected"
        if command -v apt-get &>/dev/null; then
            INSTALL_CMD="apt"
        elif command -v dnf &>/dev/null; then
            INSTALL_CMD="dnf"
        elif command -v yum &>/dev/null; then
            INSTALL_CMD="yum"
        elif command -v pacman &>/dev/null; then
            INSTALL_CMD="pacman"
        else
            error "No supported package manager found (apt, dnf, yum, pacman)"
        fi
        ;;
    *)
        error "Unsupported OS: $OS"
        ;;
esac

step "Checking for OpenBao installation"

if command -v bao &>/dev/null; then
    info "OpenBao already installed: $(bao version 2>/dev/null || echo 'unknown version')"
else
    info "OpenBao not found. Installing..."
    case "$INSTALL_CMD" in
        brew)
            run brew tap openbao/tap 2>/dev/null || true
            run brew install openbao
            ;;
        apt)
            # OpenBao provides .deb packages via GitHub releases
            warn "For apt-based systems, install from https://github.com/openbao/openbao/releases"
            warn "Or use: wget <release-url>.deb && sudo dpkg -i openbao_*.deb"
            if ! $DRY_RUN; then
                error "Automatic apt installation not yet supported. Install manually and re-run."
            fi
            ;;
        dnf|yum)
            warn "For RPM-based systems, install from https://github.com/openbao/openbao/releases"
            if ! $DRY_RUN; then
                error "Automatic RPM installation not yet supported. Install manually and re-run."
            fi
            ;;
        pacman)
            run sudo pacman -S openbao
            ;;
    esac

    if ! $DRY_RUN && ! command -v bao &>/dev/null; then
        error "OpenBao installation failed. Please install manually and re-run."
    fi
    info "OpenBao installed successfully"
fi

# ---------------------------------------------------------------------------
# Step 2: Create repo-side directory structure
# ---------------------------------------------------------------------------
step "Creating repo directory structure"

run mkdir -p "${REPO_OPENBAO_DIR}/data"

info "Created ${REPO_OPENBAO_DIR}/"
info "Created ${REPO_OPENBAO_DIR}/data/"

# ---------------------------------------------------------------------------
# Step 3: Generate config.hcl
# ---------------------------------------------------------------------------
step "Generating config.hcl"

CONFIG_FILE="${REPO_OPENBAO_DIR}/config.hcl"

if [ -f "$CONFIG_FILE" ] && ! $DRY_RUN; then
    warn "config.hcl already exists. Backing up to config.hcl.bak"
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
fi

if $DRY_RUN; then
    info "[DRY-RUN] Would write config.hcl to ${CONFIG_FILE}"
else
    cat > "$CONFIG_FILE" <<EOF
# OpenBao configuration for Precision-MOD
# File storage backend — encrypted data stored in .openbao/data/
# This directory is safe to commit to git (data is AES-256-GCM encrypted)

storage "file" {
  path = "${REPO_OPENBAO_DIR}/data"
}

# Localhost-only listener — no TLS needed for local development
listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = 1
}

# Disable the web UI (CLI-only workflow)
ui = false

# Disable mlock for development (not recommended in production)
disable_mlock = true
EOF
    info "Written ${CONFIG_FILE}"
fi

# ---------------------------------------------------------------------------
# Step 4: Create ~/.openbao/ directory and start script
# ---------------------------------------------------------------------------
step "Creating home directory structure"

run mkdir -p "${HOME_OPENBAO_DIR}"

START_SCRIPT="${HOME_OPENBAO_DIR}/start.sh"

if $DRY_RUN; then
    info "[DRY-RUN] Would write start.sh to ${START_SCRIPT}"
else
    cat > "$START_SCRIPT" <<'STARTEOF'
#!/usr/bin/env bash
# =============================================================================
# start.sh — Start and unseal OpenBao for Precision-MOD
#
# This script:
#   1. Starts the OpenBao server in background if not already running
#   2. Auto-unseals using the stored unseal key
#   3. Exports BAO_ADDR and BAO_TOKEN for the current shell
#
# Usage: source ~/.openbao/start.sh
# =============================================================================

set -euo pipefail

BAO_ADDR="http://127.0.0.1:8200"
export BAO_ADDR

INIT_KEYS_FILE="${HOME}/.openbao/init-keys.json"
CONFIG_FILE=""

# Find config.hcl — search common locations
for candidate in \
    "$(git rev-parse --show-toplevel 2>/dev/null)/.openbao/config.hcl" \
    "./.openbao/config.hcl"; do
    if [ -f "$candidate" ]; then
        CONFIG_FILE="$candidate"
        break
    fi
done

if [ -z "$CONFIG_FILE" ]; then
    echo "[ERROR] Cannot find .openbao/config.hcl. Run setup-openbao.sh first." >&2
    return 1 2>/dev/null || exit 1
fi

if [ ! -f "$INIT_KEYS_FILE" ]; then
    echo "[ERROR] Init keys not found at ${INIT_KEYS_FILE}. Run setup-openbao.sh first." >&2
    return 1 2>/dev/null || exit 1
fi

# Check if server is already running
if curl -s "${BAO_ADDR}/v1/sys/health" &>/dev/null; then
    echo "[INFO] OpenBao server already running at ${BAO_ADDR}"
else
    echo "[INFO] Starting OpenBao server..."
    nohup bao server -config="$CONFIG_FILE" > "${HOME}/.openbao/server.log" 2>&1 &
    echo $! > "${HOME}/.openbao/server.pid"

    # Wait for server to be ready
    for i in $(seq 1 10); do
        if curl -s "${BAO_ADDR}/v1/sys/health" &>/dev/null; then
            break
        fi
        sleep 1
    done

    if ! curl -s "${BAO_ADDR}/v1/sys/health" &>/dev/null; then
        echo "[ERROR] Server failed to start. Check ${HOME}/.openbao/server.log" >&2
        return 1 2>/dev/null || exit 1
    fi
    echo "[INFO] Server started (PID: $(cat "${HOME}/.openbao/server.pid"))"
fi

# Check seal status and unseal if needed
SEALED=$(curl -s "${BAO_ADDR}/v1/sys/seal-status" | grep -o '"sealed":true' || true)

if [ -n "$SEALED" ]; then
    echo "[INFO] Vault is sealed. Unsealing..."
    UNSEAL_KEY=$(grep -o '"unseal_keys_b64":\["[^"]*"' "$INIT_KEYS_FILE" | sed 's/.*\["//' | sed 's/"//')
    bao operator unseal "$UNSEAL_KEY" > /dev/null
    echo "[INFO] Vault unsealed successfully"
else
    echo "[INFO] Vault is already unsealed"
fi

# Export root token for convenience
ROOT_TOKEN=$(grep -o '"root_token":"[^"]*"' "$INIT_KEYS_FILE" | sed 's/"root_token":"//' | sed 's/"//')
export BAO_TOKEN="$ROOT_TOKEN"

echo "[INFO] BAO_ADDR=${BAO_ADDR}"
echo "[INFO] BAO_TOKEN set (root token)"
echo "[INFO] OpenBao ready. Run 'bao status' to verify."
STARTEOF

    chmod +x "$START_SCRIPT"
    info "Written ${START_SCRIPT}"
fi

# ---------------------------------------------------------------------------
# Step 5: Initialize the vault
# ---------------------------------------------------------------------------
step "Initializing OpenBao vault"

INIT_KEYS_FILE="${HOME_OPENBAO_DIR}/init-keys.json"

if [ -f "$INIT_KEYS_FILE" ] && ! $DRY_RUN; then
    info "Init keys already exist at ${INIT_KEYS_FILE}. Skipping initialization."
    info "To re-initialize, remove ${INIT_KEYS_FILE} and ${REPO_OPENBAO_DIR}/data/"
else
    # Start server temporarily for initialization
    if ! $DRY_RUN; then
        info "Starting OpenBao server for initialization..."
        export BAO_ADDR
        nohup bao server -config="$CONFIG_FILE" > "${HOME_OPENBAO_DIR}/server.log" 2>&1 &
        SERVER_PID=$!
        echo "$SERVER_PID" > "${HOME_OPENBAO_DIR}/server.pid"

        # Wait for server
        for i in $(seq 1 15); do
            if curl -s "${BAO_ADDR}/v1/sys/health" &>/dev/null; then
                break
            fi
            sleep 1
        done

        if ! curl -s "${BAO_ADDR}/v1/sys/health" &>/dev/null; then
            error "Server failed to start. Check ${HOME_OPENBAO_DIR}/server.log"
        fi
        info "Server started (PID: ${SERVER_PID})"

        # Initialize with single key share
        info "Initializing vault with 1 key share, 1 key threshold..."
        bao operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT_KEYS_FILE"

        if [ ! -s "$INIT_KEYS_FILE" ]; then
            error "Initialization failed. No output from 'bao operator init'."
        fi

        chmod 600 "$INIT_KEYS_FILE"
        info "Init keys saved to ${INIT_KEYS_FILE} (mode 600)"
    else
        info "[DRY-RUN] Would initialize vault and save keys to ${INIT_KEYS_FILE}"
    fi
fi

# ---------------------------------------------------------------------------
# Step 6: Unseal and create KV v2 secret engine
# ---------------------------------------------------------------------------
step "Unsealing vault and configuring secret engine"

if ! $DRY_RUN; then
    # Read keys
    UNSEAL_KEY=$(grep -o '"unseal_keys_b64":\["[^"]*"' "$INIT_KEYS_FILE" | sed 's/.*\["//' | sed 's/"//')
    ROOT_TOKEN=$(grep -o '"root_token":"[^"]*"' "$INIT_KEYS_FILE" | sed 's/"root_token":"//' | sed 's/"//')

    if [ -z "$UNSEAL_KEY" ] || [ -z "$ROOT_TOKEN" ]; then
        error "Failed to parse unseal key or root token from ${INIT_KEYS_FILE}"
    fi

    # Unseal
    info "Unsealing vault..."
    bao operator unseal "$UNSEAL_KEY" > /dev/null
    info "Vault unsealed"

    # Authenticate
    export BAO_TOKEN="$ROOT_TOKEN"

    # Enable KV v2 secret engine (idempotent — ignore error if already enabled)
    info "Enabling KV v2 secret engine at ${KV_MOUNT}/..."
    if bao secrets enable -version=2 -path="$KV_MOUNT" kv 2>/dev/null; then
        info "KV v2 engine enabled at ${KV_MOUNT}/"
    else
        info "KV v2 engine already enabled at ${KV_MOUNT}/ (or error — check manually)"
    fi
else
    info "[DRY-RUN] Would unseal vault and enable KV v2 engine"
fi

# ---------------------------------------------------------------------------
# Step 7: Ensure .openbao/ is tracked in git
# ---------------------------------------------------------------------------
step "Configuring git"

GITIGNORE="${REPO_ROOT}/.gitignore"

# Ensure .openbao/ is NOT in .gitignore (it should be committed)
if [ -f "$GITIGNORE" ]; then
    if grep -q '\.openbao/' "$GITIGNORE" 2>/dev/null; then
        warn ".openbao/ is in .gitignore — the encrypted data is safe to commit."
        warn "Consider removing the .openbao/ entry from .gitignore."
    fi
fi

# Ensure ~/.openbao/ is never accidentally committed
# (It is outside the repo, so this is just a safety reminder)
info "Master keys are stored at ${HOME_OPENBAO_DIR}/init-keys.json"
info "This file is outside the repo and will NEVER be committed to git."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
step "Setup complete"

cat <<SUMMARY

  OpenBao has been configured for Precision-MOD.

  Repo-side (safe to commit):
    ${REPO_OPENBAO_DIR}/config.hcl    — server configuration
    ${REPO_OPENBAO_DIR}/data/          — encrypted vault storage

  Home directory (NEVER commit):
    ${HOME_OPENBAO_DIR}/init-keys.json — master unseal key and root token
    ${HOME_OPENBAO_DIR}/start.sh       — start/unseal convenience script
    ${HOME_OPENBAO_DIR}/server.log     — server log output
    ${HOME_OPENBAO_DIR}/server.pid     — server process ID

  To start OpenBao in future sessions:
    source ~/.openbao/start.sh

  To verify:
    export BAO_ADDR=http://127.0.0.1:8200
    bao status
    bao kv list secret/

  To store a credential:
    bao kv put secret/myproject/db password=s3cret username=admin

SUMMARY

# Stop the server if we started it (user should use start.sh going forward)
if ! $DRY_RUN && [ -f "${HOME_OPENBAO_DIR}/server.pid" ]; then
    info "Stopping initialization server. Use 'source ~/.openbao/start.sh' to start again."
    kill "$(cat "${HOME_OPENBAO_DIR}/server.pid")" 2>/dev/null || true
fi
