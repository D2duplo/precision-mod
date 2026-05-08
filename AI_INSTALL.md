# Precision-MOD v2.1.0 -- Installation and Integration Guide

**Audience:** humans and AI agents bootstrapping the framework in a new codebase.
**Version:** 2.1.0
**Repository:** <https://github.com/D2duplo/precision-mod>

---

## 1. What Precision-MOD Does

Precision-MOD (Precision-checked Engineering Change Rules, Intent, Safety, I/O, Operations, and Non-negotiable Modifications) is a rulebook for AI coding agents. It enforces:

- **Planning discipline** -- no code changes without an approved plan (except micro-changes under strict conditions).
- **Git safety** -- three-tier command classification (allowed / authorized / forbidden) with optional hook enforcement.
- **Credential management** -- hard-lock against plaintext secrets in tracked files. Backend (OpenBao, HashiCorp Vault, 1Password / Bitwarden CLI, cloud Secrets Managers, system keychain) is optional and project-specific.
- **Session persistence** -- structured session logs with identity detection, enabling cross-session and cross-agent context.
- **Documentation discipline** -- mandatory updates to `filetree.md`, `planning_journal.md`, and commit messages in Conventional Commits format.
- **Context window management** -- proactive compaction when usage exceeds 40%.

The rulebook is **codebase-agnostic**. It works with any language, framework, or build system. Project-specific rules live in `AI_Guidelines/codebase_rules.md`, not in the rulebook itself.

---

## 2. Prerequisites

**Required:**

- A Git repository (initialized with `git init` or cloned).
- At least one AI coding agent: Claude Code, Cursor, Windsurf, Gemini CLI, Codex CLI, or a local LLM with tool-use capabilities.

**Optional:**

- **Obsidian** -- for vault integration, MCP bridge, and template management.
- **Secret manager** -- only if the project handles credentials. Pick whichever fits: OpenBao (self-hosted, offline; reference scripts shipped with this repo), HashiCorp Vault, 1Password CLI / Bitwarden CLI, AWS / GCP / Azure Secrets Manager, or the system keychain. See Section 7.

---

## 3. Installation Methods

### Method A: Git Clone (recommended for tracking upstream updates)

```bash
mkdir -p AI_Guidelines
git clone https://github.com/D2duplo/precision-mod.git AI_Guidelines/precision-mod-upstream
cp AI_Guidelines/precision-mod-upstream/PRECISION_MOD_RULEBOOK.md AI_Guidelines/PRECISION_MOD_RULEBOOK.md
```

To update later:

```bash
cd AI_Guidelines/precision-mod-upstream && git pull && cd -
# Review changes, then copy the updated rulebook:
cp AI_Guidelines/precision-mod-upstream/PRECISION_MOD_RULEBOOK.md AI_Guidelines/PRECISION_MOD_RULEBOOK.md
```

### Method B: Git Submodule

```bash
git submodule add https://github.com/D2duplo/precision-mod.git AI_Guidelines/precision-mod-upstream
cp AI_Guidelines/precision-mod-upstream/PRECISION_MOD_RULEBOOK.md AI_Guidelines/PRECISION_MOD_RULEBOOK.md
```

To update later:

```bash
git submodule update --remote AI_Guidelines/precision-mod-upstream
cp AI_Guidelines/precision-mod-upstream/PRECISION_MOD_RULEBOOK.md AI_Guidelines/PRECISION_MOD_RULEBOOK.md
git add AI_Guidelines/precision-mod-upstream AI_Guidelines/PRECISION_MOD_RULEBOOK.md
git commit -m "chore: update Precision-MOD to latest upstream"
```

### Method C: Direct Copy (simplest, no upstream tracking)

```bash
mkdir -p AI_Guidelines
curl -o AI_Guidelines/PRECISION_MOD_RULEBOOK.md \
  https://raw.githubusercontent.com/D2duplo/precision-mod/main/PRECISION_MOD_RULEBOOK.md
```

No automated update mechanism. Re-run the `curl` command to pull newer versions manually.

---

## 4. Bootstrap -- Directory Structure

Create the required directories and placeholder files:

```bash
# Core directories
mkdir -p AI_Guidelines/hooks
mkdir -p AI_SKILLS
mkdir -p AI_tasks/{planned,queued,in_progress,_completed}
mkdir -p .ai/commands
mkdir -p _templates
mkdir -p 99_Inbox/session-logs

# Git placeholders (keep empty dirs in version control)
touch AI_tasks/planned/.gitkeep
touch AI_tasks/queued/.gitkeep
touch AI_tasks/in_progress/.gitkeep
touch AI_tasks/_completed/.gitkeep
touch 99_Inbox/session-logs/.gitkeep
```

Resulting layout:

```
<project-root>/
  AI_Guidelines/
    PRECISION_MOD_RULEBOOK.md      # the rulebook (copied from upstream)
    precision-mod-upstream/         # upstream clone or submodule
    codebase_rules.md               # project-specific rules
    hooks/
      git-safe.sh                   # optional PreToolUse hook
  AI_SKILLS/
    INDEX.md                        # skills registry
  AI_tasks/
    planned/                        # plans being written
    queued/                         # plans ready, waiting for execution
    in_progress/                    # exactly 1 active plan
    _completed/                     # archived completed plans
  .ai/
    commands/                       # cross-agent skill files
  _templates/                       # Obsidian/shared templates
  99_Inbox/
    session-logs/                   # session persistence logs
  AGENTS.md                         # cross-agent entry point
  CLAUDE.md                         # Claude Code pointer
  GEMINI.md                         # Gemini CLI pointer
  filetree.md                       # project structure index
  planning_journal.md               # activity journal
```

---

## 5. Create Required Files

### 5.1 AGENTS.md (cross-agent entry point)

Create `AGENTS.md` at the repository root. This is the single entry point that all agents read.

```markdown
# <Project Name>

> **Owner:** <Your Name>
> **Language:** <preferred language, e.g., English, PT-PT>

MANDATORY: At the start of every task, read `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`, `filetree.md`, and `AI_SKILLS/INDEX.md`.
If `pre_compact_task_progress.md` exists, read it first (before any other action), then read the rulebook, the active plan (if any), and `filetree.md`, delete `pre_compact_task_progress.md`, and continue.

## Project Overview

<Brief description of what this project does, its main components, and its current state.>

## Tech Stack

<List languages, frameworks, databases, infrastructure.>

## Key References

| Document | Path | Purpose |
|---|---|---|
| Rulebook | `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` | Hard constraints and workflow |
| Codebase rules | `AI_Guidelines/codebase_rules.md` | Project-specific conventions |
| Skills index | `AI_SKILLS/INDEX.md` | Available agent skills |
| File tree | `filetree.md` | Project structure |
| Planning journal | `planning_journal.md` | Activity log |

## Credentials

<If using a secret manager, document the backend and available paths here.>
<Example: All credentials in OpenBao. See `AI_Guidelines/codebase_rules.md` for paths.>
<NEVER store actual secrets in this file.>
```

### 5.2 AI_Guidelines/codebase_rules.md

```markdown
# Codebase Rules

Project-specific rules that complement the Precision-MOD rulebook.

## Architecture Overview

<Describe the high-level architecture: monolith, microservices, monorepo, etc.>

## Tech Stack

| Component | Technology | Version |
|---|---|---|
| Language | | |
| Framework | | |
| Database | | |
| Build tool | | |

## Code Modification Rules

- <e.g., "All changes to `src/core/` require a plan.">
- <e.g., "Never modify generated files in `dist/`.">

## Coding Standards

- <e.g., "Follow PEP 8 for Python.">
- <e.g., "Use ESLint config in `.eslintrc.js`.">

## Testing Requirements

- <e.g., "All new functions require unit tests.">
- <e.g., "Run `npm test` before committing.">

## Database Rules

<If applicable: migration workflow, schema update process, backup requirements.>

## Credential Paths

<If using a secret manager, list available paths and their fields.>

| Path | Service | Fields |
|---|---|---|
| `<backend> <path>` | <service name> | <field list> |
```

### 5.3 AI_SKILLS/INDEX.md

```markdown
# AI Skills Index

Skills available to all agents. Canonical location: `.ai/commands/`.

| Skill | File | Description |
|---|---|---|
| `/session-save` | `.ai/commands/session-save.md` | Save session log at end of session |
| `/session-load` | `.ai/commands/session-load.md` | Load context from previous sessions |

## Adding New Skills

1. Create the skill file in `.ai/commands/<name>.md`.
2. Add an entry to this index.
3. For Claude Code: symlink to `~/.claude/commands/` if slash command access is desired.
4. Validate compatibility with all agents that use the project.
```

### 5.4 filetree.md

```markdown
# File Tree

Project structure index. Updated by agents when files are added or removed.
Do NOT list `AI_tasks/` entries here.

```text
<project-root>/
  AI_Guidelines/
    PRECISION_MOD_RULEBOOK.md
    codebase_rules.md
    hooks/
  AI_SKILLS/
    INDEX.md
  .ai/
    commands/
  _templates/
  99_Inbox/
    session-logs/
  AGENTS.md
  CLAUDE.md
  filetree.md
  planning_journal.md
```
```

### 5.5 planning_journal.md

```markdown
# Planning Journal

Activity log. New entries at the top. Language: English.

---
```

### 5.6 .gitignore additions

Append the following lines to `.gitignore` (create it if it does not exist):

```
# Obsidian vault metadata (personal UI preferences)
.obsidian/

# Precision-MOD compaction state (transient)
pre_compact_task_progress.md
```

---

## 6. Configure Agent Entry Points

Each AI agent has its own configuration file that points to `AGENTS.md`. This avoids duplicating instructions across agents.

### 6.1 Claude Code

Create `CLAUDE.md` at the repository root:

```markdown
# Claude Code -- see AGENTS.md

All instructions in `AGENTS.md`. Read `AGENTS.md` at session start.
```

Optionally, symlink skills for slash command access:

```bash
mkdir -p ~/.claude/commands
ln -sf "$(pwd)/.ai/commands/session-save.md" ~/.claude/commands/session-save.md
ln -sf "$(pwd)/.ai/commands/session-load.md" ~/.claude/commands/session-load.md
```

### 6.2 Cursor

Create `.cursor/rules/precision-mod.mdc`:

```markdown
---
description: Precision-MOD rulebook integration
globs: ["**/*"]
alwaysApply: true
---

Read `AGENTS.md` at the start of every task. Follow all rules in `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`.
```

### 6.3 Gemini CLI

Create `GEMINI.md` at the repository root:

```markdown
# Gemini CLI -- see AGENTS.md

All instructions in `AGENTS.md`. Read `AGENTS.md` at session start.
```

### 6.4 Windsurf

Windsurf reads `AGENTS.md` natively. No additional configuration file is required. Verify that the agent reads `AGENTS.md` at session start.

### 6.5 Codex CLI

Codex CLI reads `AGENTS.md` natively. No additional configuration file is required.

---

## 7. Optional: Credential Management

This section applies only if the project handles secrets. If it does not, skip it.

The hard-lock is **no plaintext secrets in tracked files** (Section 2.2 of the rulebook). The backend you use to keep that promise is your choice and lives in `AI_Guidelines/codebase_rules.md`.

### 7.1 Pick a Backend

| Backend | Best for | Repo footprint |
|---|---|---|
| **OpenBao** (reference shipped with Precision-MOD) | Self-hosted, offline, file-based vault; encrypted blob safe to commit | `.openbao/` directory in repo |
| **HashiCorp Vault** | Existing infra, multi-user policies | None (server-side) |
| **1Password CLI / Bitwarden CLI** | Personal projects, small teams already using these tools | None |
| **AWS / GCP / Azure Secrets Manager** | Cloud-native deployments | None |
| **System keychain** (macOS Keychain, GNOME Keyring, libsecret) | Single-developer setups, no team sharing | None |
| **`.env` in `.gitignore`** | Quick prototypes only — accept the risks | None tracked |

### 7.2 Document the Choice

In `AI_Guidelines/codebase_rules.md`, add a "Credential Management" section that names the backend, the bootstrap commands, and the paths/items in use. Reference values by location, never by value.

OpenBao example:

```markdown
## Credential Management

**Backend:** OpenBao at `http://127.0.0.1:8200`
**Bootstrap:** `~/.openbao/start.sh`

| Path | Service | Fields |
|---|---|---|
| `project/database` | MySQL | username, password, host |
| `project/api` | External API | api_key, secret |
```

1Password CLI example:

```markdown
## Credential Management

**Backend:** 1Password CLI (`op`) — vault `Eng/Prod`
**Bootstrap:** `op signin`

| Item | Service | Fields |
|---|---|---|
| `Eng/Prod/Database` | MySQL | username, password, host |
| `Eng/Prod/API` | External API | api_key, secret |
```

### 7.3 OpenBao — Turnkey Setup (only if you chose OpenBao)

```bash
bash AI_Guidelines/precision-mod-upstream/scripts/setup-openbao.sh
```

This will:
- Install OpenBao (brew on macOS, package manager on Linux)
- Create `.openbao/config.hcl` in the repo (file storage backend)
- Create `~/.openbao/start.sh` (auto-unseal startup script)
- Initialize the vault, save master key to `~/.openbao/init-keys.json`
- Create a KV v2 secret engine

For the full OpenBao guide (architecture, daily commands, team sharing, threat model), see `docs/credential-management.md`.

### 7.4 Migrate Existing Plaintext Credentials

If the codebase already has hardcoded credentials (`.env` files, AGENTS.md, code):

**OpenBao users:**

```bash
# Scan only (no changes)
bash AI_Guidelines/precision-mod-upstream/scripts/migrate-credentials.sh --scan-only

# Interactive migration
bash AI_Guidelines/precision-mod-upstream/scripts/migrate-credentials.sh

# Batch migration with mapping file
bash AI_Guidelines/precision-mod-upstream/scripts/migrate-credentials.sh --batch migrate-map.txt
```

**Other backends:** the same pattern applies — scan for credential patterns, store the values in your backend, replace plaintext values with location references (e.g., `1Password "Eng/Prod/DB"`, `aws-sm:project/api-key`). The OpenBao migration script can be adapted as a template.

> After any migration, old plaintext values remain in git history. Use `git filter-repo` or `bfg` to scrub if the values were sensitive.

### 7.5 Agent Instructions

In `AGENTS.md`, add a short pointer that names the backend, the bootstrap command, and the read/write commands (and remind agents that secrets must never be written to files or echoed). Example for OpenBao:

```markdown
## Credentials — OpenBao

NEVER store secrets in tracked files. All credentials in OpenBao.

\`\`\`bash
~/.openbao/start.sh                          # start if not running
export BAO_ADDR=http://127.0.0.1:8200
bao kv get -field=password <path>            # read
bao kv put <path> username=x password=y      # write
\`\`\`

Reference in docs as: `OpenBao <path>`
```

For 1Password CLI, AWS Secrets Manager, etc., write the equivalent block.

---

## 8. Optional: Session Persistence

Session persistence enables cross-session and cross-agent context continuity. Agents save structured logs at the end of each session and load them at the start of the next.

### 8.1 Setup Steps

1. **Create skill files** in `.ai/commands/`:

   **`.ai/commands/session-save.md`** -- end-of-session skill:
   ```markdown
   # /session-save -- Save session

   Save a structured session log to `99_Inbox/session-logs/`.

   ## Filename format
   `YYYY-MM-DD-HH_MM-<host_short>-<agent_type>-<topic>.md`

   ## Procedure
   1. Detect identity fields (host, user, agent_type, model).
   2. Summarize work done, decisions made, and open items.
   3. Reference the active `AI_tasks/in_progress/` plan (if any).
   4. Write the session log with mandatory frontmatter.
   5. Update `planning_journal.md` with an entry.
   ```

   **`.ai/commands/session-load.md`** -- start-of-session skill:
   ```markdown
   # /session-load -- Resume session

   Load context from previous sessions.

   ## Procedure
   1. Read the latest session logs in `99_Inbox/session-logs/`.
   2. Read `AI_tasks/in_progress/` for active plans.
   3. Read `pre_compact_task_progress.md` if it exists.
   4. Summarize loaded context to the user.
   ```

2. **Ensure the session log directory exists:**
   ```bash
   mkdir -p 99_Inbox/session-logs
   touch 99_Inbox/session-logs/.gitkeep
   ```

3. **Session log frontmatter** (mandatory for all logs):
   ```yaml
   ---
   type: session-log
   date: YYYY-MM-DD
   status: complete | partial
   tags: [ai-generated, session-log]

   # Identity
   host: <full hostname>
   user: <git config user.name>
   agent_type: <agent slug: claude-code | cursor | windsurf | gemini-cli | codex-cli | local-llm | human>
   agent_version: "<tool version>"
   model: <model identifier>

   # Context
   project: <directory name>
   topic: <same as filename topic>
   active_task: AI_tasks/in_progress/<plan>.md  # optional
   ---
   ```

4. **Identity detection** -- agents populate fields automatically:
   - `host` -- output of `hostname`
   - `user` -- output of `git config user.name`
   - `agent_type` -- auto-detect from environment (e.g., `CLAUDECODE=1` means `claude-code`)
   - `agent_version` -- tool version string
   - `model` -- model identifier from system prompt or user override

---

## 9. Optional: Obsidian Vault Integration

When the repository is also used as an Obsidian knowledge base.

### 9.1 Setup Steps

1. **Open the repo as an Obsidian vault:**
   - Obsidian > File > Open Folder as Vault > select the repository root.

2. **Add `.obsidian/` to `.gitignore`:**
   ```
   .obsidian/
   ```
   This directory contains personal UI preferences and plugin settings. It must not be committed.

3. **Install the `claude-code-mcp` plugin** (for MCP integration with Claude Code):
   - Obsidian > Settings > Community plugins > Browse > search `claude-code-mcp` > Install > Enable.

4. **Configure the plugin port** in Obsidian settings:
   - Settings > Community plugins > claude-code-mcp > set `mcpHttpPort` (e.g., `22360`).
   - Note: the setting field is `mcpHttpPort`, not `ssePort`.

5. **Register the MCP server with Claude Code:**
   ```bash
   claude mcp add --transport sse --scope user obsidian-vault http://localhost:22360/sse
   ```
   Replace `22360` with the port configured in step 4.

6. **Verify the connection:**
   - Ensure Obsidian is running (the MCP plugin only works when Obsidian is open).
   - In Claude Code, verify the MCP is accessible.

7. **Shared templates** go in `_templates/` at the repository root (git-tracked). Obsidian-specific template settings point to this directory.

---

## 10. Optional: Git Safety Hook

The git safety hook enforces the three-tier git command classification as a `PreToolUse` hook. This provides deterministic, 100% compliance -- the agent cannot bypass the rules even if instructed to.

### 10.1 Install the Hook Script

Copy the reference implementation to your project:

```bash
cp AI_Guidelines/precision-mod-upstream/scripts/git-safe.sh AI_Guidelines/hooks/git-safe.sh
chmod +x AI_Guidelines/hooks/git-safe.sh
```

The reference implementation is at `scripts/git-safe.sh` in this repository. It handles all three tiers with JSON output for forward compatibility with Claude Code hooks.

### 10.2 Register the Hook

For **Claude Code**, add the hook to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash AI_Guidelines/hooks/git-safe.sh \"$TOOL_INPUT\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

For other agents, consult the agent's documentation for hook/plugin integration. The script is a standard bash script that reads tool input as its first argument and exits with code 0 (allow) or 2 (block).

---

## 11. Verification Checklist

After installation, verify that all required components are in place.

```
[ ] AI_Guidelines/PRECISION_MOD_RULEBOOK.md exists and is readable
[ ] AI_Guidelines/codebase_rules.md exists (even if minimal)
[ ] AI_SKILLS/INDEX.md exists with at least the /session-save and /session-load entries
[ ] AI_tasks/planned/ directory exists with .gitkeep
[ ] AI_tasks/queued/ directory exists with .gitkeep
[ ] AI_tasks/in_progress/ directory exists with .gitkeep
[ ] AI_tasks/_completed/ directory exists with .gitkeep
[ ] AGENTS.md exists at repo root and contains the mandatory initialization text
[ ] filetree.md exists at repo root
[ ] planning_journal.md exists at repo root
[ ] .gitignore contains ".obsidian/" and "pre_compact_task_progress.md"
[ ] Agent reads the rulebook at session start (test with a new session)
[ ] Credential manager accessible (if configured) -- verify with backend status command
[ ] 99_Inbox/session-logs/ directory exists with .gitkeep
[ ] Git safety hook blocks "git reset --hard" (if configured) -- test manually
```

Quick verification script:

```bash
#!/usr/bin/env bash
# verify-precision-mod.sh -- Run from the repository root.

PASS=0
FAIL=0

check() {
  if eval "$2"; then
    echo "  [OK] $1"
    ((PASS++))
  else
    echo "  [FAIL] $1"
    ((FAIL++))
  fi
}

echo "Precision-MOD v2.1.0 -- Installation Verification"
echo "---------------------------------------------------"

check "Rulebook exists" "[ -f AI_Guidelines/PRECISION_MOD_RULEBOOK.md ]"
check "Codebase rules exist" "[ -f AI_Guidelines/codebase_rules.md ]"
check "Skills index exists" "[ -f AI_SKILLS/INDEX.md ]"
check "AI_tasks/planned/ exists" "[ -d AI_tasks/planned ]"
check "AI_tasks/queued/ exists" "[ -d AI_tasks/queued ]"
check "AI_tasks/in_progress/ exists" "[ -d AI_tasks/in_progress ]"
check "AI_tasks/_completed/ exists" "[ -d AI_tasks/_completed ]"
check "AGENTS.md exists" "[ -f AGENTS.md ]"
check "filetree.md exists" "[ -f filetree.md ]"
check "planning_journal.md exists" "[ -f planning_journal.md ]"
check ".gitignore contains .obsidian/" "grep -q '.obsidian/' .gitignore 2>/dev/null"
check ".gitignore contains pre_compact_task_progress.md" "grep -q 'pre_compact_task_progress.md' .gitignore 2>/dev/null"
check "Session logs directory exists" "[ -d 99_Inbox/session-logs ]"

echo "---------------------------------------------------"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "All checks passed." || echo "Fix the failures above before using Precision-MOD."
```

---

## 12. Updating from v1.x

If the project already uses Precision-MOD v1.x, follow these migration steps.

### 12.1 Back Up the Existing Rulebook

```bash
cp AI_Guidelines/PRECISION_MOD_RULEBOOK.md AI_Guidelines/PRECISION_MOD_RULEBOOK.md.v1.bak
```

### 12.2 Pull or Copy the v2.0.0 Rulebook

Using Method A (clone):

```bash
cd AI_Guidelines/precision-mod-upstream && git pull && cd -
cp AI_Guidelines/precision-mod-upstream/PRECISION_MOD_RULEBOOK.md AI_Guidelines/PRECISION_MOD_RULEBOOK.md
```

Using Method C (direct copy):

```bash
curl -o AI_Guidelines/PRECISION_MOD_RULEBOOK.md \
  https://raw.githubusercontent.com/D2duplo/precision-mod/main/PRECISION_MOD_RULEBOOK.md
```

### 12.3 Review Git Rules Changes

v2.0.0 replaces the blanket "forbidden" list from v1.x with a three-tier classification:

| Previously forbidden | v2.0.0 status | Notes |
|---|---|---|
| `git add` | Tier 1 (allowed) | No longer requires confirmation |
| `git commit` | Tier 1 (allowed) | Agent must present full message first |
| `git checkout <branch>` | Tier 1 (allowed) | Normal workflow |
| `git stash` / `git stash pop` | Tier 1 (allowed) | Save/restore temporary work |
| `git push` | Tier 2 (authorized) | Requires user confirmation |
| `git checkout -- <file>` | Tier 2 (authorized) | Requires user confirmation |
| `git reset --hard` | Tier 3 (forbidden) | Still forbidden |
| `git push --force` to main | Tier 3 (forbidden) | Still forbidden |
| `git clean -fd` | Tier 3 (forbidden) | Still forbidden |

Review any custom git restrictions in your `codebase_rules.md` and reconcile with the new tiers.

### 12.4 Add Credential Management

If the project handles secrets, add a Credential Management section to `AI_Guidelines/codebase_rules.md` (see Section 7 above). The hard-lock — introduced in v2.0.0 and clarified in v2.1.0 — is "no plaintext secrets in tracked files". The choice of backend (OpenBao, HashiCorp Vault, 1Password / Bitwarden CLI, AWS / GCP / Azure Secrets Manager, system keychain) is optional and project-specific. If the project does not handle secrets, this subsection can be skipped entirely.

### 12.5 Update Session Log Format

v2.0.0 introduces mandatory identity fields in session log frontmatter:

```yaml
# Identity (new in v2.0.0)
host: <full hostname>
user: <git config user.name>
agent_type: <agent slug>
agent_version: "<tool version>"
model: <model identifier>
```

Existing session logs do not need to be retroactively updated (the rulebook forbids rewriting history). New logs must include these fields.

### 12.6 Consider Adding the Git Safety Hook

v2.0.0 introduces the `PreToolUse` hook mechanism for deterministic enforcement (see Section 10). This is optional but recommended for teams where multiple agents operate concurrently.

### 12.7 Update AGENTS.md

Replace the mandatory initialization text in `AGENTS.md` with the current version:

```
MANDATORY: At the start of every task, read `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`, `filetree.md`, and `AI_SKILLS/INDEX.md`.
If `pre_compact_task_progress.md` exists, read it first (before any other action), then read the rulebook, the active plan (if any), and `filetree.md`, delete `pre_compact_task_progress.md`, and continue.
```

### 12.8 Updating from v2.0.0 to v2.1.0

v2.1.0 is a non-breaking minor bump.

- **Section 2.2 (Credential Management)** is now explicit that the secret-manager backend is optional. The hard-lock remains "no plaintext secrets in tracked files". Projects already running OpenBao need no changes — it stays the recommended reference implementation, only repositioned as one of several supported options.
- **Bootstrap and Quick Start** no longer presume OpenBao. `scripts/setup-openbao.sh` is opt-in.
- **`docs/credential-management.md`** is now the OpenBao-specific guide and points to alternative backends.

To adopt v2.1.0:

```bash
cd AI_Guidelines/precision-mod-upstream && git pull && cd -
cp AI_Guidelines/precision-mod-upstream/PRECISION_MOD_RULEBOOK.md AI_Guidelines/PRECISION_MOD_RULEBOOK.md
```

If you have not chosen a credential backend yet, document the choice (or document that the project handles no secrets) in `AI_Guidelines/codebase_rules.md`.

---

## Quick Start (All-in-One)

For a fresh repository, run the following sequence after installing the rulebook (Section 3):

```bash
# 1. Create directory structure
mkdir -p AI_Guidelines/hooks AI_SKILLS AI_tasks/{planned,queued,in_progress,_completed} .ai/commands _templates 99_Inbox/session-logs
touch AI_tasks/planned/.gitkeep AI_tasks/queued/.gitkeep AI_tasks/in_progress/.gitkeep AI_tasks/_completed/.gitkeep 99_Inbox/session-logs/.gitkeep

# 2. Create CLAUDE.md (adjust for your agent)
cat > CLAUDE.md << 'EOF'
# Claude Code -- see AGENTS.md
All instructions in `AGENTS.md`. Read `AGENTS.md` at session start.
EOF

# 3. Create minimal .gitignore additions
echo '.obsidian/' >> .gitignore
echo 'pre_compact_task_progress.md' >> .gitignore

# 4. Create skeleton files (edit these with project-specific content)
touch AGENTS.md filetree.md planning_journal.md AI_Guidelines/codebase_rules.md AI_SKILLS/INDEX.md

# 5. Make the git safety hook executable (if using it)
# chmod +x AI_Guidelines/hooks/git-safe.sh

# 6. Initial commit
git add -A
git commit -m "chore: bootstrap Precision-MOD v2.1.0"
```

Then populate `AGENTS.md`, `AI_Guidelines/codebase_rules.md`, `AI_SKILLS/INDEX.md`, `filetree.md`, and `planning_journal.md` with the templates from Section 5.

---

## References

- **Rulebook:** `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` (local copy)
- **Upstream repository:** <https://github.com/D2duplo/precision-mod>
- **Changelog:** see upstream repository releases for version history
