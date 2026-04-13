#!/usr/bin/env bash
# =============================================================================
# migrate-credentials.sh — Scan and migrate plaintext credentials to OpenBao
#
# Scans the codebase for plaintext credentials (passwords, tokens, API keys)
# and interactively migrates them into OpenBao KV v2 secret engine.
#
# Usage: ./migrate-credentials.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || pwd)"
BAO_ADDR="${BAO_ADDR:-http://127.0.0.1:8200}"
KV_MOUNT="secret"
SCAN_ONLY=false
DRY_RUN=false
BATCH_MODE=false
BATCH_MAP_FILE=""
FINDINGS_FILE=""

# Track results for the report phase
MIGRATED=()
SKIPPED=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf "[INFO]  %s\n" "$*"; }
warn()  { printf "[WARN]  %s\n" "$*" >&2; }
error() { printf "[ERROR] %s\n" "$*" >&2; exit 1; }
step()  { printf "\n==> %s\n" "$*"; }

# Mask a value: show first 2 chars, then ***
mask_value() {
    local val="$1"
    if [ ${#val} -le 2 ]; then
        printf "%s***" "$val"
    else
        printf "%s***" "${val:0:2}"
    fi
}

usage() {
    cat <<'USAGE'
migrate-credentials.sh — Scan and migrate plaintext credentials to OpenBao

Usage:
    ./migrate-credentials.sh [OPTIONS]

Options:
    --help          Show this help message and exit
    --dry-run       Show what would be done without making changes
    --scan-only     Scan and report findings, do not migrate anything
    --batch FILE    Non-interactive batch mode using a mapping file

Scan Phase:
    Searches for credential patterns in:
      - .env files (KEY=VALUE with password/token/secret/key in the name)
      - AGENTS.md / CLAUDE.md / GEMINI.md (plaintext credential values)
      - Python/JS/PHP files with hardcoded credentials
      - YAML/JSON config with credential-like keys
      - Docker Compose files with environment secrets

Interactive Migration:
    For each credential found, the script:
      1. Shows file, line, key name (value masked)
      2. Asks for the OpenBao path (suggests a default)
      3. Stores the credential in OpenBao via 'bao kv put'
      4. Replaces the plaintext value with an OpenBao reference

Batch Mode:
    Use --batch with a mapping file. Format:
      # migrate-map.txt
      .env:DB_PASSWORD -> project/database password
      .env:API_KEY -> project/api api_key
      AGENTS.md:25 -> project/service password

    Each line: SOURCE:KEY -> BAO_PATH BAO_KEY_NAME

USAGE
    exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --help)      usage ;;
        --dry-run)   DRY_RUN=true; shift ;;
        --scan-only) SCAN_ONLY=true; shift ;;
        --batch)
            BATCH_MODE=true
            shift
            if [ $# -eq 0 ]; then
                error "--batch requires a mapping file argument"
            fi
            BATCH_MAP_FILE="$1"
            shift
            ;;
        *)
            error "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
step "Pre-flight checks"

if ! $SCAN_ONLY; then
    if ! command -v bao &>/dev/null; then
        error "OpenBao (bao) not found. Run setup-openbao.sh first."
    fi

    # Check if vault is accessible and unsealed
    if ! bao status &>/dev/null; then
        warn "OpenBao is not running or is sealed."
        warn "Run: source ~/.openbao/start.sh"
        if ! $DRY_RUN; then
            error "Cannot proceed without a running, unsealed vault."
        fi
    fi
fi

if $BATCH_MODE && [ ! -f "$BATCH_MAP_FILE" ]; then
    error "Batch mapping file not found: $BATCH_MAP_FILE"
fi

info "Repository root: ${REPO_ROOT}"
info "Scan only: ${SCAN_ONLY}"
info "Dry run: ${DRY_RUN}"
info "Batch mode: ${BATCH_MODE}"

# ---------------------------------------------------------------------------
# Temporary file for findings
# ---------------------------------------------------------------------------
FINDINGS_FILE=$(mktemp /tmp/migrate-creds-XXXXXX.txt)
trap 'rm -f "$FINDINGS_FILE"' EXIT

# ---------------------------------------------------------------------------
# Scan Phase
# ---------------------------------------------------------------------------
step "Scanning for plaintext credentials"

TOTAL_FOUND=0

# --- Scan .env files ---
scan_env_files() {
    local env_files
    env_files=$(find "$REPO_ROOT" -name '.env' -o -name '.env.*' -not -name '.env.example' 2>/dev/null | grep -v node_modules | grep -v .git || true)

    for envfile in $env_files; do
        local relpath="${envfile#${REPO_ROOT}/}"
        local count=0
        local keys=""

        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$line" ]] && continue

            # Match KEY=VALUE where KEY contains credential-like words
            if echo "$line" | grep -qiE '^[A-Z_]*(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|APIKEY|AUTH|CREDENTIAL|PRIVATE_KEY|ACCESS_KEY)[A-Z_]*='; then
                local key=$(echo "$line" | cut -d= -f1)
                local value=$(echo "$line" | cut -d= -f2-)
                # Skip empty values and placeholder values
                if [ -n "$value" ] && ! echo "$value" | grep -qE '^\$\{|^<|^your_|^changeme|^xxx'; then
                    count=$((count + 1))
                    keys="${keys:+${keys}, }${key}"
                    local linenum=$(grep -n "^${key}=" "$envfile" | head -1 | cut -d: -f1)
                    echo "ENV|${relpath}|${linenum}|${key}|${value}" >> "$FINDINGS_FILE"
                fi
            fi
        done < "$envfile"

        if [ $count -gt 0 ]; then
            printf "  FOUND: %s -- %d potential credentials (%s)\n" "$relpath" "$count" "$keys"
            TOTAL_FOUND=$((TOTAL_FOUND + count))
        fi
    done
}

# --- Scan agent/AI instruction files for plaintext credentials ---
scan_agent_files() {
    local agent_files
    agent_files=$(find "$REPO_ROOT" -maxdepth 3 \( -name 'AGENTS.md' -o -name 'CLAUDE.md' -o -name 'GEMINI.md' -o -name 'AI_Guidelines*.md' \) -not -path '*/.git/*' 2>/dev/null || true)

    for agentfile in $agent_files; do
        local relpath="${agentfile#${REPO_ROOT}/}"
        local linenum=0

        while IFS= read -r line; do
            linenum=$((linenum + 1))

            # Look for patterns like "password: xyz", "token: abc123", etc.
            if echo "$line" | grep -qiE '(password|token|secret|api.?key|credential)[[:space:]]*[:=][[:space:]]*[^ ]{4,}'; then
                # Extract the key and value
                local key=$(echo "$line" | grep -oiE '(password|token|secret|api.?key|credential)' | head -1)
                local value=$(echo "$line" | sed -E 's/.*[:=][[:space:]]*//' | sed 's/[[:space:]]*$//')

                # Skip lines that are clearly references to OpenBao or documentation
                if echo "$line" | grep -qiE 'OpenBao|bao kv|vault|example|placeholder'; then
                    continue
                fi

                if [ -n "$value" ] && [ ${#value} -gt 3 ]; then
                    printf "  FOUND: %s:%d -- plaintext %s detected\n" "$relpath" "$linenum" "$key"
                    echo "AGENT|${relpath}|${linenum}|${key}|${value}" >> "$FINDINGS_FILE"
                    TOTAL_FOUND=$((TOTAL_FOUND + 1))
                fi
            fi
        done < "$agentfile"
    done
}

# --- Scan code files for hardcoded credentials ---
scan_code_files() {
    local code_files
    code_files=$(find "$REPO_ROOT" \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.php' -o -name '*.rb' -o -name '*.go' \) -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' -not -path '*/venv/*' 2>/dev/null || true)

    for codefile in $code_files; do
        local relpath="${codefile#${REPO_ROOT}/}"

        # Search for hardcoded credential assignments
        grep -nEi '(password|passwd|api_key|apikey|secret_key|auth_token|access_token|private_key)[[:space:]]*=[[:space:]]*["\x27][^"\x27]{4,}["\x27]' "$codefile" 2>/dev/null | while IFS=: read -r linenum content; do
            # Skip comments
            if echo "$content" | grep -qE '^[[:space:]]*(#|//|/\*|\*)'; then
                continue
            fi
            # Skip variable references and env lookups
            if echo "$content" | grep -qiE 'os\.environ|getenv|process\.env|ENV\['; then
                continue
            fi

            local key=$(echo "$content" | grep -oiE '(password|passwd|api_key|apikey|secret_key|auth_token|access_token|private_key)' | head -1)
            local value=$(echo "$content" | grep -oE '["\x27][^"\x27]{4,}["\x27]' | head -1 | tr -d "\"'")

            if [ -n "$value" ]; then
                printf "  FOUND: %s:%s -- hardcoded %s in code\n" "$relpath" "$linenum" "$key"
                echo "CODE|${relpath}|${linenum}|${key}|${value}" >> "$FINDINGS_FILE"
                TOTAL_FOUND=$((TOTAL_FOUND + 1))
            fi
        done
    done
}

# --- Scan YAML/JSON config files ---
scan_config_files() {
    local config_files
    config_files=$(find "$REPO_ROOT" \( -name '*.yml' -o -name '*.yaml' -o -name '*.json' \) -not -name 'package-lock.json' -not -name 'node_modules' -not -path '*/.git/*' -not -path '*/node_modules/*' -not -name '*.schema.json' 2>/dev/null || true)

    for cfgfile in $config_files; do
        local relpath="${cfgfile#${REPO_ROOT}/}"

        grep -nEi '(password|secret|token|api_key|apikey|auth|credential|private_key)["\x27]?[[:space:]]*:[[:space:]]*["\x27]?[^"\x27[:space:]{}\[\]]{4,}' "$cfgfile" 2>/dev/null | while IFS=: read -r linenum content; do
            # Skip comments
            if echo "$content" | grep -qE '^[[:space:]]*(#|//)'; then
                continue
            fi

            local key=$(echo "$content" | grep -oiE '(password|secret|token|api_key|apikey|auth|credential|private_key)' | head -1)

            printf "  FOUND: %s:%s -- credential-like key '%s' in config\n" "$relpath" "$linenum" "$key"
            echo "CONFIG|${relpath}|${linenum}|${key}|" >> "$FINDINGS_FILE"
            TOTAL_FOUND=$((TOTAL_FOUND + 1))
        done
    done
}

# --- Scan Docker Compose files ---
scan_docker_compose() {
    local compose_files
    compose_files=$(find "$REPO_ROOT" \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'compose.yml' -o -name 'compose.yaml' \) -not -path '*/.git/*' 2>/dev/null || true)

    for composefile in $compose_files; do
        local relpath="${composefile#${REPO_ROOT}/}"

        grep -nEi '(PASSWORD|SECRET|TOKEN|API_KEY|APIKEY|AUTH)[A-Z_]*[[:space:]]*[:=]' "$composefile" 2>/dev/null | while IFS=: read -r linenum content; do
            local key=$(echo "$content" | grep -oE '[A-Z_]*(PASSWORD|SECRET|TOKEN|API_KEY|APIKEY|AUTH)[A-Z_]*' | head -1)
            local value=$(echo "$content" | sed -E 's/.*[:=][[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")

            if [ -n "$key" ]; then
                printf "  FOUND: %s:%s -- %s in Docker Compose environment\n" "$relpath" "$linenum" "$key"
                echo "DOCKER|${relpath}|${linenum}|${key}|${value}" >> "$FINDINGS_FILE"
                TOTAL_FOUND=$((TOTAL_FOUND + 1))
            fi
        done
    done
}

# Run all scanners
info "Scanning .env files..."
scan_env_files

info "Scanning agent instruction files..."
scan_agent_files

info "Scanning code files..."
scan_code_files

info "Scanning YAML/JSON config files..."
scan_config_files

info "Scanning Docker Compose files..."
scan_docker_compose

# ---------------------------------------------------------------------------
# Scan Results Summary
# ---------------------------------------------------------------------------
step "Scan results"

FINDING_COUNT=$(wc -l < "$FINDINGS_FILE" | tr -d ' ')
info "Found ${FINDING_COUNT} potential credentials across the codebase"

if [ "$FINDING_COUNT" -eq 0 ]; then
    info "No plaintext credentials found. Codebase looks clean."
    exit 0
fi

if $SCAN_ONLY; then
    info "Scan-only mode. No migration performed."
    info "Re-run without --scan-only to migrate credentials to OpenBao."
    exit 0
fi

# ---------------------------------------------------------------------------
# Batch Mode
# ---------------------------------------------------------------------------
if $BATCH_MODE; then
    step "Batch migration from ${BATCH_MAP_FILE}"

    while IFS= read -r mapping; do
        # Skip comments and empty lines
        [[ "$mapping" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$mapping" ]] && continue

        # Parse: source:key -> bao_path bao_key
        source_part=$(echo "$mapping" | sed 's/[[:space:]]*->.*$//')
        target_part=$(echo "$mapping" | sed 's/^.*->[[:space:]]*//')

        source_file=$(echo "$source_part" | cut -d: -f1)
        source_key=$(echo "$source_part" | cut -d: -f2)
        bao_path=$(echo "$target_part" | awk '{print $1}')
        bao_key=$(echo "$target_part" | awk '{print $2}')

        if [ -z "$bao_path" ] || [ -z "$bao_key" ]; then
            warn "Skipping malformed mapping: $mapping"
            SKIPPED+=("$mapping (malformed)")
            continue
        fi

        # Find the value in the source file
        full_path="${REPO_ROOT}/${source_file}"
        if [ ! -f "$full_path" ]; then
            warn "Source file not found: ${source_file}"
            SKIPPED+=("${source_file}:${source_key} (file not found)")
            continue
        fi

        value=""
        if [[ "$source_key" =~ ^[0-9]+$ ]]; then
            # Line number reference
            value=$(sed -n "${source_key}p" "$full_path" | sed -E 's/.*[:=][[:space:]]*//' | sed 's/[[:space:]]*$//')
        else
            # Key name reference
            value=$(grep -E "^${source_key}=" "$full_path" 2>/dev/null | head -1 | cut -d= -f2-)
        fi

        if [ -z "$value" ]; then
            warn "Could not extract value for ${source_file}:${source_key}"
            SKIPPED+=("${source_file}:${source_key} (no value found)")
            continue
        fi

        info "Migrating ${source_file}:${source_key} -> ${KV_MOUNT}/${bao_path} (key: ${bao_key})"

        if $DRY_RUN; then
            info "[DRY-RUN] Would store $(mask_value "$value") at ${KV_MOUNT}/${bao_path}"
        else
            bao kv put "${KV_MOUNT}/${bao_path}" "${bao_key}=${value}" > /dev/null
        fi

        MIGRATED+=("${source_file}:${source_key} -> ${KV_MOUNT}/${bao_path}#${bao_key}")

    done < "$BATCH_MAP_FILE"

    # Skip interactive migration
    # Fall through to report phase
fi

# ---------------------------------------------------------------------------
# Interactive Migration
# ---------------------------------------------------------------------------
if ! $BATCH_MODE; then
    step "Interactive migration"
    info "For each credential, you can migrate it to OpenBao or skip it."
    echo ""

    while IFS='|' read -r type relpath linenum key value; do
        echo "--------------------------------------------------------------"
        printf "  File:  %s (line %s)\n" "$relpath" "$linenum"
        printf "  Type:  %s\n" "$type"
        printf "  Key:   %s\n" "$key"
        if [ -n "$value" ]; then
            printf "  Value: %s\n" "$(mask_value "$value")"
        else
            printf "  Value: (could not extract — manual review needed)\n"
        fi
        echo ""

        # Suggest a default OpenBao path based on file location
        dir_name=$(dirname "$relpath" | tr '/' '-' | sed 's/^-//' | sed 's/^\.$/project/')
        suggested_path="${dir_name}/$(echo "$key" | tr '[:upper:]' '[:lower:]')"
        printf "  Suggested OpenBao path: %s/%s\n" "$KV_MOUNT" "$suggested_path"
        echo ""

        read -rp "  Enter OpenBao path (or 'skip' / 's' to skip): " user_path </dev/tty

        if [ "$user_path" = "skip" ] || [ "$user_path" = "s" ] || [ -z "$user_path" ]; then
            info "Skipped: ${relpath}:${key}"
            SKIPPED+=("${relpath}:${linenum}:${key}")
            echo ""
            continue
        fi

        # Use suggested path if user just presses enter with default
        final_path="$user_path"
        bao_key_name=""
        read -rp "  Key name in OpenBao (default: $(echo "$key" | tr '[:upper:]' '[:lower:]')): " bao_key_name </dev/tty
        bao_key_name="${bao_key_name:-$(echo "$key" | tr '[:upper:]' '[:lower:]')}"

        if [ -z "$value" ]; then
            read -rp "  Value could not be auto-extracted. Enter value manually: " value </dev/tty
            if [ -z "$value" ]; then
                warn "No value provided. Skipping."
                SKIPPED+=("${relpath}:${linenum}:${key} (no value)")
                continue
            fi
        fi

        # Store in OpenBao
        if $DRY_RUN; then
            info "[DRY-RUN] Would run: bao kv put ${KV_MOUNT}/${final_path} ${bao_key_name}=***"
        else
            if bao kv put "${KV_MOUNT}/${final_path}" "${bao_key_name}=${value}" > /dev/null 2>&1; then
                info "Stored at ${KV_MOUNT}/${final_path}#${bao_key_name}"
            else
                warn "Failed to store credential. Is the vault unsealed?"
                SKIPPED+=("${relpath}:${linenum}:${key} (bao kv put failed)")
                continue
            fi
        fi

        # Replace plaintext in source file
        full_path="${REPO_ROOT}/${relpath}"
        if ! $DRY_RUN; then
            case "$type" in
                ENV)
                    # Comment out the original line and add migration note
                    sed -i.bak "${linenum}s/^/# [MIGRATED] /" "$full_path"
                    sed -i.bak "${linenum}a\\
# Migrated to OpenBao ${KV_MOUNT}/${final_path}#${bao_key_name}" "$full_path"
                    rm -f "${full_path}.bak"
                    ;;
                AGENT)
                    # Replace value with OpenBao reference
                    sed -i.bak "${linenum}s|${value}|OpenBao ${KV_MOUNT}/${final_path}|" "$full_path"
                    rm -f "${full_path}.bak"
                    ;;
                CODE)
                    # Add a comment above the line with the OpenBao path
                    comment_prefix="#"
                    case "$relpath" in
                        *.js|*.ts|*.php|*.go) comment_prefix="//" ;;
                    esac
                    sed -i.bak "${linenum}i\\
${comment_prefix} TODO: migrate to OpenBao ${KV_MOUNT}/${final_path}#${bao_key_name}" "$full_path"
                    rm -f "${full_path}.bak"
                    ;;
                CONFIG|DOCKER)
                    # Add a comment noting the migration
                    sed -i.bak "${linenum}s/^/# [MIGRATED to OpenBao ${KV_MOUNT}\/${final_path}] /" "$full_path"
                    rm -f "${full_path}.bak"
                    ;;
            esac
            info "Updated ${relpath} with OpenBao reference"
        else
            info "[DRY-RUN] Would update ${relpath} with OpenBao reference"
        fi

        MIGRATED+=("${relpath}:${linenum}:${key} -> ${KV_MOUNT}/${final_path}#${bao_key_name}")
        echo ""

    done < "$FINDINGS_FILE"
fi

# ---------------------------------------------------------------------------
# Report Phase
# ---------------------------------------------------------------------------
step "Migration report"

echo ""
echo "  Migrated credentials: ${#MIGRATED[@]}"
for item in "${MIGRATED[@]}"; do
    printf "    [OK] %s\n" "$item"
done

echo ""
echo "  Skipped credentials: ${#SKIPPED[@]}"
for item in "${SKIPPED[@]}"; do
    printf "    [--] %s\n" "$item"
done

echo ""
echo "--------------------------------------------------------------"
echo "  IMPORTANT: Git History Warning"
echo "--------------------------------------------------------------"
echo ""
echo "  Plaintext credential values may still exist in git history."
echo "  Removing them from files does NOT remove them from past commits."
echo ""
echo "  To clean git history, consider one of:"
echo ""
echo "    1. git filter-repo (recommended):"
echo "       pip install git-filter-repo"
echo "       git filter-repo --invert-paths --path <file-with-secrets>"
echo ""
echo "    2. BFG Repo-Cleaner:"
echo "       brew install bfg"
echo "       bfg --replace-text passwords.txt"
echo "       git reflog expire --expire=now --all"
echo "       git gc --prune=now --aggressive"
echo ""
echo "  After history rewrite, all collaborators must re-clone."
echo "--------------------------------------------------------------"
