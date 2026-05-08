#!/usr/bin/env bash
# Precision-MOD v2.2.1 — Installation Script
# Usage: bash <upstream>/scripts/install.sh [--with-obsidian] [--with-hooks] [--root <path>]
#
# Bootstraps the Precision-MOD directory structure in the PARENT project,
# copies the rulebook and session skills, and optionally configures Obsidian
# vault integration and git safety hooks.
#
# Project root is auto-detected. When precision-mod is used as a git submodule,
# the script targets the superproject's working tree, NOT the submodule itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="$(dirname "$SCRIPT_DIR")"

# Parse arguments first so --root takes effect before REPO_ROOT detection.
WITH_OBSIDIAN=false
WITH_HOOKS=false
EXPLICIT_ROOT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --with-obsidian) WITH_OBSIDIAN=true; shift ;;
    --with-hooks)    WITH_HOOKS=true; shift ;;
    --root)
      if [ $# -lt 2 ]; then
        echo "ERROR: --root requires a path argument" >&2
        exit 2
      fi
      EXPLICIT_ROOT="$2"; shift 2 ;;
    --help|-h)
      cat <<USAGE
Usage: $0 [--with-obsidian] [--with-hooks] [--root <path>]

  --with-obsidian  Configure repo as Obsidian vault (.obsidian/ in .gitignore)
  --with-hooks     Install git-safe PreToolUse hook for Claude Code
  --root <path>    Explicit project root (override auto-detection)
USAGE
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Resolve REPO_ROOT (the PARENT project root, never the precision-mod clone).
#
# Resolution order:
#   1. --root <path> (explicit override)
#   2. Superproject working tree — when precision-mod is a git submodule
#   3. Toplevel of the directory containing UPSTREAM_DIR — when precision-mod
#      is a regular clone whose parent dir is itself a git repo
#   4. Current working directory (last resort)
#
# Then: refuse to proceed if REPO_ROOT == UPSTREAM_DIR or sits inside it.
# Bootstrapping inside the precision-mod clone is never correct (this is the
# bug v2.2.1 fixes).
# ---------------------------------------------------------------------------

REPO_ROOT=""

if [ -n "$EXPLICIT_ROOT" ]; then
  REPO_ROOT="$(cd "$EXPLICIT_ROOT" 2>/dev/null && pwd || true)"
  if [ -z "$REPO_ROOT" ]; then
    echo "ERROR: --root path does not exist or is not accessible: $EXPLICIT_ROOT" >&2
    exit 1
  fi
else
  # Submodule case: ask the upstream's git for the superproject.
  SUPERPROJECT="$(git -C "$UPSTREAM_DIR" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
  if [ -n "$SUPERPROJECT" ]; then
    REPO_ROOT="$SUPERPROJECT"
  else
    # Non-submodule clone case: the parent of UPSTREAM_DIR may itself be a
    # git repo (the user's project). Its toplevel is the parent project root.
    PARENT="$(dirname "$UPSTREAM_DIR")"
    PARENT_TOP="$(git -C "$PARENT" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$PARENT_TOP" ] && [ "$PARENT_TOP" != "$UPSTREAM_DIR" ]; then
      REPO_ROOT="$PARENT_TOP"
    fi
  fi

  # Last resort.
  if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$(pwd)"
  fi
fi

# Safety guard: REPO_ROOT must not equal or be inside UPSTREAM_DIR.
case "$REPO_ROOT/" in
  "$UPSTREAM_DIR/"|"$UPSTREAM_DIR"/*)
    cat >&2 <<ERR
ERROR: detected REPO_ROOT inside the precision-mod upstream directory.
       REPO_ROOT     = $REPO_ROOT
       UPSTREAM_DIR  = $UPSTREAM_DIR

This would bootstrap precision-mod's directory structure INSIDE the clone
itself, which is never correct. Re-run from the parent project root, or
pass --root <path> explicitly:

  bash $UPSTREAM_DIR/scripts/install.sh --root /path/to/your/project
ERR
    exit 1
    ;;
esac

echo "=== Precision-MOD v2.2.1 — Bootstrap ==="
echo "Repo root:    $REPO_ROOT"
echo "Upstream dir: $UPSTREAM_DIR"
echo ""

# 1. Create directory structure
echo "[1/8] Creating directory structure..."
mkdir -p "$REPO_ROOT/AI_Guidelines/hooks"
mkdir -p "$REPO_ROOT/AI_SKILLS"
mkdir -p "$REPO_ROOT/AI_tasks/planned"
mkdir -p "$REPO_ROOT/AI_tasks/queued"
mkdir -p "$REPO_ROOT/AI_tasks/in_progress"
mkdir -p "$REPO_ROOT/AI_tasks/_completed"
mkdir -p "$REPO_ROOT/.ai/commands"
mkdir -p "$REPO_ROOT/_templates"
mkdir -p "$REPO_ROOT/99_Inbox/session-logs"

for dir in AI_tasks/planned AI_tasks/queued AI_tasks/in_progress AI_tasks/_completed 99_Inbox/session-logs; do
  touch "$REPO_ROOT/$dir/.gitkeep"
done

# 2. Copy rulebook (if not already present)
echo "[2/8] Installing rulebook..."
if [ ! -f "$REPO_ROOT/AI_Guidelines/PRECISION_MOD_RULEBOOK.md" ]; then
  cp "$UPSTREAM_DIR/PRECISION_MOD_RULEBOOK.md" "$REPO_ROOT/AI_Guidelines/PRECISION_MOD_RULEBOOK.md"
  echo "  Copied rulebook to AI_Guidelines/"
else
  echo "  Rulebook already exists — skipping (update manually if needed)"
fi

# 3. Create codebase_rules.md template (if not exists)
echo "[3/8] Creating codebase_rules.md template..."
if [ ! -f "$REPO_ROOT/AI_Guidelines/codebase_rules.md" ]; then
  cat > "$REPO_ROOT/AI_Guidelines/codebase_rules.md" << 'CODEBASERULES'
# Codebase Rules

**Version:** 1.0.0 | **Updated:** $(date +%Y-%m-%d)

Project-specific rules. Supplements `PRECISION_MOD_RULEBOOK.md`.

## 1. Project Overview
<!-- Describe your project here -->

## 2. Tech Stack
<!-- Languages, frameworks, versions -->

## 3. Code Modification Rules
<!-- Which directories are editable, which are forbidden -->

## 4. Credential Management
<!-- OPTIONAL — only if this project handles secrets.
     Hard-lock: no plaintext secrets in tracked files.
     Backend choice is project-specific (OpenBao, HashiCorp Vault,
     1Password / Bitwarden CLI, AWS / GCP / Azure Secrets Manager,
     system keychain, .gitignore'd .env). Document the chosen backend,
     bootstrap commands, and paths/items below. -->
<!-- Example (OpenBao):
**Backend:** OpenBao
```bash
~/.openbao/start.sh           # bootstrap
export BAO_ADDR=http://127.0.0.1:8200
bao kv get -field=password <path>
```
-->
<!-- Example (1Password CLI):
**Backend:** 1Password CLI (`op`) — vault `Eng/Prod`
```bash
op signin                                      # bootstrap
op item get "Eng/Prod/DB" --fields password
```
-->

## 5. Testing Requirements
<!-- How to run tests, what must pass before commit -->

## 6. Project-Specific Constraints
<!-- Any project-specific hard rules -->

## 7. Production-Flagged Targets (Section 2.3 of rulebook)
<!-- List environments, scripts, services, and credentials that count as
     production. The agent must not act on these without explicit, scoped
     authorization. -->

## 8. Sensitive Data (Section 2.4 of rulebook)
<!-- Categories that must be anonymized in tracked artefacts, with the
     placeholder scheme used for each (e.g., [PERSON], [ACCOUNT], masked
     digits, location pointers). -->

## 9. Privileged Tooling Wrappers (Section 7 of rulebook)
<!-- Wrappers the agent must use instead of the underlying CLI for
     privileged operations (database access, deploys, secret retrieval,
     container exec, etc.). -->

## 10. Verification Gates (Section 9 of rulebook)
<!-- Default verification gates by task type. For investigative tasks,
     define exit-criterion templates instead. -->

## 11. Cross-Repository Sync Points (Section 14 of rulebook)
<!-- Local files / configs whose change requires updating a sibling
     repository, and which sibling. -->

## 12. Issue Tracking — In-Repo Folders (Section 15 of rulebook, optional)
<!-- If using BUGS/ and FEATURES/ folders: ID format, required files,
     lifecycle state names, severity scale. Skip if relying solely on
     external trackers. -->
CODEBASERULES
  echo "  Created template — edit to match your project"
else
  echo "  codebase_rules.md already exists — skipping"
fi

# 4. Copy session skills (new in v2.2.1 — was a manual step before)
echo "[4/8] Installing session skills..."
for skill in session-save session-load; do
  src="$UPSTREAM_DIR/skills/${skill}.md"
  dst="$REPO_ROOT/.ai/commands/${skill}.md"
  if [ -f "$dst" ]; then
    echo "  $skill.md already exists — skipping"
  elif [ -f "$src" ]; then
    cp "$src" "$dst"
    echo "  Copied $skill.md to .ai/commands/"
  else
    echo "  WARNING: $src not found in upstream — skipping"
  fi
done

# 5. Create AI_SKILLS/INDEX.md (if not exists)
echo "[5/8] Creating AI_SKILLS/INDEX.md..."
if [ ! -f "$REPO_ROOT/AI_SKILLS/INDEX.md" ]; then
  cat > "$REPO_ROOT/AI_SKILLS/INDEX.md" << 'SKILLSINDEX'
# AI Skills Index

**Version:** 1.0.0

Skills available for all agents. Canonical location: `.ai/commands/`.

## Available Skills

| Skill | Command | Path | Description |
|-------|---------|------|-------------|
| Save session | `/session-save` | `.ai/commands/session-save.md` | End of session: save structured summary |
| Load context | `/session-load` | `.ai/commands/session-load.md` | Start of session: load previous context |

## Usage by Agent

| Agent | How to invoke |
|-------|---------------|
| Claude Code | `/session-save`, `/session-load` (symlink to `~/.claude/commands/`) |
| Cursor / Windsurf / Gemini / Codex | Read `.ai/commands/<skill>.md` and follow instructions |

## Adding New Skills

1. Create skill in `.ai/commands/<name>.md`
2. Update this INDEX.md
3. For Claude Code: `ln -sf $(pwd)/.ai/commands/<name>.md ~/.claude/commands/<name>.md`
SKILLSINDEX
  echo "  Created AI_SKILLS/INDEX.md"
else
  echo "  INDEX.md already exists — skipping"
fi

# 6. Create stub files
echo "[6/8] Creating stub files..."

if [ ! -f "$REPO_ROOT/filetree.md" ]; then
  echo "# Filetree" > "$REPO_ROOT/filetree.md"
  echo "" >> "$REPO_ROOT/filetree.md"
  echo "Codebase structure index. Updated by agents when files are added." >> "$REPO_ROOT/filetree.md"
  echo "  Created filetree.md"
fi

if [ ! -f "$REPO_ROOT/planning_journal.md" ]; then
  echo "# Planning Journal" > "$REPO_ROOT/planning_journal.md"
  echo "" >> "$REPO_ROOT/planning_journal.md"
  echo "## $(date +%Y-%m-%d)" >> "$REPO_ROOT/planning_journal.md"
  echo "- **Summary:** Precision-MOD v2.2.1 bootstrapped" >> "$REPO_ROOT/planning_journal.md"
  echo "- **Next:** Configure codebase_rules.md for this project" >> "$REPO_ROOT/planning_journal.md"
  echo "  Created planning_journal.md"
fi

if [ ! -f "$REPO_ROOT/AGENTS.md" ]; then
  cat > "$REPO_ROOT/AGENTS.md" << 'AGENTSMD'
# Project Name

> **Owner:** Your Name
> **Language:** en

MANDATORY: At the start of every task, read `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`, `filetree.md`, and `AI_SKILLS/INDEX.md`.
If `pre_compact_task_progress.md` exists, read it first (before any other action), then read the rulebook, the active plan (if any), and `filetree.md`, delete `pre_compact_task_progress.md`, and continue.

## Precision-MOD

Rulebook at `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` (v2.2.1). Project rules at `AI_Guidelines/codebase_rules.md`.

## Session Persistence

| Skill | Command | Description |
|-------|---------|-------------|
| Save | `/session-save` | End of session: save context |
| Load | `/session-load` | Start of session: load context |

Session logs at `99_Inbox/session-logs/`.

## Workflow

```
Start:   /session-load (or read .ai/commands/session-load.md)
Work:    Follow planning discipline (AI_tasks/)
End:     /session-save (or read .ai/commands/session-save.md)
```
AGENTSMD
  echo "  Created AGENTS.md template"
else
  echo "  AGENTS.md already exists — skipping"
fi

if [ ! -f "$REPO_ROOT/CLAUDE.md" ]; then
  cat > "$REPO_ROOT/CLAUDE.md" << 'CLAUDEMD'
# Claude Code — see AGENTS.md

All instructions in `AGENTS.md`. Read `AGENTS.md` at session start.
CLAUDEMD
  echo "  Created CLAUDE.md pointer"
fi

# 7. Update .gitignore
echo "[7/8] Updating .gitignore..."
GITIGNORE="$REPO_ROOT/.gitignore"
touch "$GITIGNORE"

add_gitignore() {
  if ! grep -qF "$1" "$GITIGNORE" 2>/dev/null; then
    echo "$1" >> "$GITIGNORE"
    echo "  Added: $1"
  fi
}

add_gitignore "pre_compact_task_progress.md"

if [ "$WITH_OBSIDIAN" = true ]; then
  add_gitignore ".obsidian/"
  echo "  Obsidian vault mode enabled"
fi

# 8. Optional: Install hooks
echo "[8/8] Hooks..."
if [ "$WITH_HOOKS" = true ]; then
  if [ -f "$UPSTREAM_DIR/scripts/git-safe.sh" ]; then
    cp "$UPSTREAM_DIR/scripts/git-safe.sh" "$REPO_ROOT/AI_Guidelines/hooks/git-safe.sh"
    chmod +x "$REPO_ROOT/AI_Guidelines/hooks/git-safe.sh"
    echo "  Installed git-safe.sh hook"
    echo ""
    echo "  To activate, add to .claude/settings.json:"
    echo '  {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash AI_Guidelines/hooks/git-safe.sh \"$TOOL_INPUT\""}]}]}}'
  else
    echo "  git-safe.sh not found in upstream — skipping"
  fi
else
  echo "  Skipped (use --with-hooks to install)"
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit AI_Guidelines/codebase_rules.md for your project"
echo "  2. Edit AGENTS.md with your project details"
echo "  3. Run: git add AI_Guidelines/ AI_SKILLS/ AI_tasks/ .ai/ AGENTS.md CLAUDE.md filetree.md planning_journal.md"
if [ "$WITH_OBSIDIAN" = true ]; then
  echo "  4. Open this directory as an Obsidian vault"
  echo "  5. Install claude-code-mcp plugin in Obsidian"
fi
echo ""
echo "Done."
