# Credential Management with OpenBao

> **OpenBao is one of several supported backends — and it is optional.** The Precision-MOD hard-lock (Rulebook §2.2) is "no plaintext secrets in tracked files". The choice of *how* you keep that promise is up to the project. OpenBao is the reference implementation Precision-MOD ships scripts for, but HashiCorp Vault, 1Password CLI / Bitwarden CLI, AWS / GCP / Azure Secrets Manager, or the system keychain are all equally valid. Pick whatever fits your threat model and operational constraints, and document the choice in `AI_Guidelines/codebase_rules.md`. This guide covers the OpenBao option specifically.

## Table of Contents

1. [Why OpenBao](#why-openbao)
2. [Architecture](#architecture)
3. [Setup](#setup)
4. [Daily Usage](#daily-usage)
5. [Agent Integration](#agent-integration)
6. [Migration from Plaintext](#migration-from-plaintext)
7. [Sharing with Team](#sharing-with-team)
8. [Security Model](#security-model)
9. [Comparison with Alternatives](#comparison-with-alternatives)
10. [Troubleshooting](#troubleshooting)

---

## Why OpenBao

[OpenBao](https://openbao.org/) is an open-source secrets management tool, forked from HashiCorp Vault after the BSL license change. It provides enterprise-grade credential management while remaining fully open-source under the MPL 2.0 license.

Key properties that make it suitable for Precision-MOD:

- **AES-256-GCM encryption** -- all data at rest is encrypted with authenticated encryption. The encrypted blob is meaningless without the master key.
- **File-based storage backend** -- no external database required. The encrypted storage lives in a directory that can be committed to git.
- **Single binary** -- no dependencies, no runtime requirements. Works on macOS, Linux, and Windows.
- **Works offline** -- no network connectivity required after installation. The vault runs entirely on localhost.
- **Audit logging** -- every read and write operation can be logged for accountability.
- **KV v2 versioning** -- secrets are versioned by default, allowing rollback to previous values.
- **API-first design** -- every operation available via CLI is also available via HTTP API, making it straightforward for scripts and agents to consume.

## Architecture

Precision-MOD uses a split-storage architecture that balances security with portability:

```
Repository (.openbao/)                 Home directory (~/.openbao/)
+---------------------------+          +---------------------------+
| config.hcl                |          | init-keys.json            |
| data/                     |          |   - unseal_key (base64)   |
|   core/                   |          |   - root_token            |
|   logical/                |          | start.sh                  |
|   sys/                    |          | server.log                |
+---------------------------+          | server.pid                |
  Encrypted, safe to commit            +---------------------------+
  AES-256-GCM at rest                    Master key, NEVER committed
```

### Repo-side: `.openbao/data/`

This directory contains the encrypted vault storage. Every secret, configuration, and metadata item is encrypted with AES-256-GCM before being written to disk. The encryption key itself is encrypted by the master key (which is derived from the unseal key).

This directory is **safe to commit to git**. Anyone who clones the repository gets the encrypted vault, but cannot read any secrets without the master key.

### Home-side: `~/.openbao/`

This directory contains the master key material:

- **`init-keys.json`** -- the unseal key and root token, generated during `bao operator init`. This file is the "key to the kingdom." Without it, the encrypted data in `.openbao/data/` is unreadable.
- **`start.sh`** -- convenience script to start and unseal the vault.
- **`server.log`** / **`server.pid`** -- runtime files.

This directory must **NEVER** be committed to git. It lives outside the repository in the user's home directory.

### How sharing works

When a new team member clones the repository:

1. They get the encrypted vault data (`.openbao/data/`).
2. They receive the master key out-of-band (see [Sharing with Team](#sharing-with-team)).
3. They run `setup-openbao.sh` which detects the existing data and configures the local environment.
4. They unseal with the shared key and have access to all stored credentials.

## Setup

Run the setup script from the repository root:

```bash
cd AI_Guidelines/precision-mod-upstream
./scripts/setup-openbao.sh
```

The script will:

1. Detect the operating system and install OpenBao if not present.
2. Create `.openbao/config.hcl` with file storage backend and localhost listener.
3. Create `~/.openbao/` with the start script.
4. Initialize the vault with a single unseal key.
5. Save the init keys to `~/.openbao/init-keys.json`.
6. Unseal and enable the KV v2 secret engine.

Use `--dry-run` to preview actions without making changes:

```bash
./scripts/setup-openbao.sh --dry-run
```

After setup, start OpenBao in future sessions:

```bash
source ~/.openbao/start.sh
```

## Daily Usage

### Environment setup

Before using `bao` commands, ensure the server is running and the environment is configured:

```bash
source ~/.openbao/start.sh
```

This sets `BAO_ADDR` and `BAO_TOKEN` in the current shell.

### Common commands

**Store a credential:**

```bash
bao kv put secret/project/database password=s3cret username=admin host=db.example.com
```

**Read a credential:**

```bash
# Full output (all fields)
bao kv get secret/project/database

# Single field
bao kv get -field=password secret/project/database
```

**List stored paths:**

```bash
# List top-level paths
bao kv list secret/

# List paths under a prefix
bao kv list secret/project/
```

**Update a credential (adds a new version):**

```bash
bao kv put secret/project/database password=newpassword username=admin
```

**Delete a credential:**

```bash
# Soft delete (recoverable)
bao kv delete secret/project/database

# Permanent delete of specific versions
bao kv destroy -versions=1,2 secret/project/database
```

**View version history:**

```bash
bao kv metadata get secret/project/database
```

**Read a previous version:**

```bash
bao kv get -version=1 secret/project/database
```

### Recommended path structure

Organize secrets by project and service:

```
secret/
  homelab/
    unifi           # UniFi controller credentials
    proxmox         # Proxmox API tokens
    mercusys        # Mercusys router credentials
  project/
    database        # Database credentials
    api             # External API keys
  infra/
    ssh             # SSH keys and passphrases
    certificates    # TLS certificate data
```

## Agent Integration

AI agents (Claude Code, Gemini, Cursor, etc.) should follow these rules when working with credentials:

### Bootstrap check

At the start of every session, agents should verify OpenBao is available:

```bash
bao status 2>/dev/null
```

If the vault is sealed or not running, instruct the user to run `source ~/.openbao/start.sh`.

### Reading credentials

Agents should read credentials on-demand using the CLI:

```bash
bao kv get -field=password secret/homelab/unifi
```

### Rules for agents

1. **Never cache credentials in files.** Read from OpenBao each time a credential is needed. Do not write credentials to temporary files, environment files, or any other persistent storage.

2. **Never store credentials in conversation context.** If an agent needs a credential, it should execute the `bao kv get` command and use the result directly. The credential value should not appear in logs, summaries, or documentation.

3. **Use the reference format in documentation.** When documenting where a credential is stored, use the format:

   ```
   OpenBao secret/homelab/unifi
   ```

   This tells other agents (and humans) where to find the credential without exposing the value.

4. **Check before writing.** Before storing a new credential, check if the path already exists:

   ```bash
   bao kv get secret/path 2>/dev/null
   ```

5. **Respect the KV path structure.** Follow the project's established path conventions (see [Recommended path structure](#recommended-path-structure)).

### Example: agent reading a credential for an API call

```bash
# Agent reads the credential
TOKEN=$(bao kv get -field=api_key secret/project/api)

# Agent uses it in a curl command
curl -H "Authorization: Bearer ${TOKEN}" https://api.example.com/data

# The token is in a shell variable, not in any file
```

## Migration from Plaintext

Use the migration script to find and migrate plaintext credentials:

```bash
cd AI_Guidelines/precision-mod-upstream
./scripts/migrate-credentials.sh
```

### Scan only (no changes)

To see what would be found without making any changes:

```bash
./scripts/migrate-credentials.sh --scan-only
```

### Interactive migration

Run without flags for interactive mode. The script will:

1. Scan the codebase for credential patterns.
2. For each finding, show the file, line, and key (value masked).
3. Ask for the OpenBao path.
4. Store the credential and update the source file.

### Batch migration

For repeatable migrations, create a mapping file:

```
# migrate-map.txt
# Format: source_file:key_or_line -> bao_path bao_key_name
.env:DB_PASSWORD -> project/database password
.env:API_KEY -> project/api api_key
AGENTS.md:25 -> homelab/service password
docker-compose.yml:MYSQL_ROOT_PASSWORD -> project/database root_password
```

Run with the mapping file:

```bash
./scripts/migrate-credentials.sh --batch migrate-map.txt
```

### After migration

The migration script will warn about credentials remaining in git history. To clean history:

```bash
# Option 1: git filter-repo (recommended)
pip install git-filter-repo
git filter-repo --invert-paths --path .env

# Option 2: BFG Repo-Cleaner
brew install bfg
bfg --replace-text passwords.txt
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

After a history rewrite, all collaborators must re-clone the repository.

## Sharing with Team

### Sharing the master key

The master key (`~/.openbao/init-keys.json`) must be shared securely and out-of-band. Recommended methods, in order of preference:

1. **In person** -- physically hand over the key on a USB drive or read it aloud.
2. **1Password / Bitwarden** -- store the key in a shared vault in a password manager.
3. **Signal (disappearing messages)** -- send via Signal with a short disappearing message timer (e.g., 1 hour).
4. **GPG-encrypted email** -- encrypt the key file with the recipient's GPG public key.

Never share the master key via:
- Unencrypted email
- Slack / Teams / Discord (even in DMs)
- Committed files in any repository
- Cloud storage without encryption (Google Drive, Dropbox, etc.)

### Onboarding a new team member

1. The new member clones the repository (gets encrypted vault data).
2. They run `./scripts/setup-openbao.sh` (installs OpenBao, creates local config).
3. You share `~/.openbao/init-keys.json` via a secure channel.
4. They place it at `~/.openbao/init-keys.json` with mode 600.
5. They run `source ~/.openbao/start.sh` to unseal and start using the vault.

### Key rotation

If the master key is compromised:

1. Create a new vault with `setup-openbao.sh` (after removing old `.openbao/data/`).
2. Re-populate credentials from the old vault (if still accessible) or from backups.
3. Distribute the new master key to all team members.
4. Ensure the old master key is revoked from all shared locations.

## Security Model

### What is protected

- **Data at rest** -- all secrets in `.openbao/data/` are encrypted with AES-256-GCM. Without the unseal key, the data is computationally infeasible to decrypt.
- **Data in transit (local)** -- the listener runs on `127.0.0.1` only. Traffic never leaves the loopback interface. TLS is not required for localhost-only communication.
- **Access control** -- OpenBao supports policies, tokens, and auth methods for multi-user environments. The default Precision-MOD setup uses a single root token for simplicity.

### What is NOT protected

- **Data in memory** -- while the vault is unsealed, secrets are decrypted in memory. Any process running as the same user on the same machine can potentially read them via `/proc` or debugging tools.
- **Shell access** -- anyone with shell access to the machine while the vault is unsealed can run `bao kv get` commands using the exported `BAO_TOKEN`.
- **Root token exposure** -- the default setup exports the root token as an environment variable. This is convenient but means any child process inherits it. In production, use scoped tokens with limited policies.
- **Git history** -- migrating credentials out of files does not remove them from git history. Use `git filter-repo` or `bfg` for history cleanup.
- **Backup exposure** -- if `~/.openbao/init-keys.json` is included in system backups (Time Machine, etc.), the master key is in those backups.

### Threat model summary

| Threat | Protected? | Notes |
|--------|-----------|-------|
| Repository leaked (GitHub, stolen laptop) | Yes | Encrypted data, no key in repo |
| Git history contains old plaintext secrets | No | Must clean with filter-repo/bfg |
| Attacker has shell access while vault is unsealed | No | Can read secrets via bao CLI |
| Attacker has only the encrypted data files | Yes | AES-256-GCM, no key = no access |
| Master key file stolen | No | Full access to all secrets |
| Network eavesdropping | Yes | Localhost-only, no network exposure |

## Comparison with Alternatives

| Feature | OpenBao | HashiCorp Vault | 1Password CLI | AWS Secrets Manager | .env files |
|---------|---------|----------------|---------------|--------------------|-----------:|
| License | MPL 2.0 (open source) | BSL 1.1 (source-available) | Proprietary | Proprietary | N/A |
| Cost | Free | Free (limited) / Paid | $2.99+/user/mo | $0.40/secret/mo | Free |
| Encryption at rest | AES-256-GCM | AES-256-GCM | AES-256 | AES-256 | None |
| Offline operation | Yes | Yes | Partial (cached) | No | Yes |
| File-based storage | Yes | Yes | No | No | Yes |
| Versioning | Yes (KV v2) | Yes (KV v2) | Yes | Yes | No (manual) |
| Audit log | Yes | Yes | Yes | Yes (CloudTrail) | No |
| Self-hosted | Yes | Yes | No | No | N/A |
| Single binary | Yes | Yes | Yes | No (SDK) | N/A |
| Safe to commit data | Yes (encrypted) | Yes (encrypted) | No | No | No |
| Requires internet | No | No | Partial | Yes | No |
| Multi-user policies | Yes | Yes | Yes | Yes (IAM) | No |
| Complexity | Medium | Medium | Low | Medium | Trivial |

**Why not .env files?** -- No encryption, easy to accidentally commit, no versioning, no audit trail. Suitable only for non-sensitive configuration.

**Why not HashiCorp Vault?** -- Functionally equivalent, but the BSL license restricts competitive use. OpenBao is a community fork that maintains full open-source status.

**Why not 1Password CLI?** -- Requires a subscription and internet access for most operations. Good for personal use but adds a dependency on a third-party service.

**Why not AWS Secrets Manager?** -- Requires AWS account, internet access, and IAM configuration. Overkill for local development and adds cloud dependency.

## Troubleshooting

### Vault is sealed

**Symptom:** `bao status` shows `Sealed: true`, or commands return `* Vault is sealed`.

**Fix:**
```bash
source ~/.openbao/start.sh
```

Or manually:
```bash
export BAO_ADDR=http://127.0.0.1:8200
UNSEAL_KEY=$(cat ~/.openbao/init-keys.json | grep -o '"unseal_keys_b64":\["[^"]*"' | sed 's/.*\["//' | sed 's/"//')
bao operator unseal "$UNSEAL_KEY"
```

### Port 8200 already in use

**Symptom:** Server fails to start with `bind: address already in use`.

**Fix:** Check what is using the port and stop it:
```bash
lsof -i :8200
kill <PID>
```

Or change the port in `.openbao/config.hcl`:
```hcl
listener "tcp" {
  address = "127.0.0.1:8201"
}
```

Then update `BAO_ADDR` accordingly.

### Permission denied on init-keys.json

**Symptom:** `start.sh` cannot read the init keys file.

**Fix:**
```bash
chmod 600 ~/.openbao/init-keys.json
```

### "connection refused" errors

**Symptom:** `bao` commands return connection refused.

**Fix:** The server is not running. Start it:
```bash
source ~/.openbao/start.sh
```

Or start manually:
```bash
bao server -config=.openbao/config.hcl &
```

### Lost master key

**Symptom:** `~/.openbao/init-keys.json` is missing or corrupted.

**Impact:** The encrypted vault data is unrecoverable without the master key. There is no backdoor or recovery mechanism -- this is by design.

**Prevention:**
- Back up `init-keys.json` to a secure location (password manager, encrypted USB).
- Share the key with at least one trusted team member.

### KV engine not enabled

**Symptom:** `bao kv` commands return `no handler for route`.

**Fix:**
```bash
bao secrets enable -version=2 -path=secret kv
```

### Server log shows "mlock not supported"

**Symptom:** Warning about mlock in server.log on macOS.

**Impact:** Non-critical. The `disable_mlock = true` setting in config.hcl handles this. In production Linux environments, enable mlock for memory protection.

### Vault data corrupted after git merge

**Symptom:** Vault fails to unseal or returns errors after a git merge involving `.openbao/data/`.

**Fix:** The encrypted data files are binary and do not merge well. Use one side of the merge:
```bash
git checkout --theirs .openbao/data/
# or
git checkout --ours .openbao/data/
```

**Prevention:** Coordinate vault changes -- only one person should write to the vault at a time, then commit and push before others pull. Treat `.openbao/data/` as a binary artifact, not mergeable text.
