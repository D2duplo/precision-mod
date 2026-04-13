#!/usr/bin/env bash
# Precision-MOD v2.0.0 — Installation Script
# Usage: bash AI_Guidelines/precision-mod-upstream/scripts/install.sh [--with-obsidian] [--with-hooks]
#
# Bootstraps the Precision-MOD directory structure, creates required files,
# and optionally configures Obsidian vault integration and git safety hooks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"

# Parse arguments
WITH_OBSIDIAN=false
WITH_HOOKS=false
for arg in "$@"; do
  case "$arg" in
    --with-obsidian) WITH_OBSIDIAN=true ;;
    --with-hooks)    WITH_HOOKS=true ;;
    --help|-h)
      echo "Usage: $0 [--with-obsidian] [--with-hooks]"
      echo ""
      echo "  --with-obsidian  Configure repo as Obsidian vault (.obsidian/ in .gitignore)"
      echo "  --with-hooks     Install git-safe PreToolUse hook for Claude Code"
      exit 0
      ;;
  esac
done

echo "=== Precision-MOD v2.0.0 — Bootstrap ==="
echo "Repo root: $REPO_ROOT"
echo ""

# 1. Create directory structure
echo "[1/7] Creating directory structure..."
mkdir -p "$REPO_ROOT/AI_Guidelines/hooks"
mkdir -p "$REPO_ROOT/AI_SKILLS"
mkdir -p "$REPO_ROOT/AI_tasks/planned"
mkdir -p "$REPO_ROOT/AI_tasks/queued"
mkdir -p "$REPO_ROOT/AI_tasks/in_progress"
mkdir -p "$REPO_ROOT/AI_tasks/_completed"
mkdir -p "$REPO_ROOT/.ai/commands"
mkdir -p "$REPO_ROOT/_templates"
mkdir -p "$REPO_ROOT/99_Inbox/session-logs"

# .gitkeep for empty dirs
for dir in AI_tasks/planned AI_tasks/queued AI_tasks/in_progress AI_tasks/_completed 99_Inbox/session-logs; do
  touch "$REPO_ROOT/$dir/.gitkeep"
done

# 2. Copy rulebook (if not already present)
echo "[2/7] Installing rulebook..."
if [ ! -f "$REPO_ROOT/AI_Guidelines/PRECISION_MOD_RULEBOOK.md" ]; then
  cp "$UPSTREAM_DIR/PRECISION_MOD_RULEBOOK.md" "$REPO_ROOT/AI_Guidelines/PRECISION_MOD_RULEBOOK.md"
  echo "  Copied rulebook to AI_Guidelines/"
else
  echo "  Rulebook already exists — skipping (update manually if needed)"
fi

# 3. Create codebase_rules.md template (if not exists)
echo "[3/7] Creating codebase_rules.md template..."
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
<!-- Secret manager backend, paths, bootstrap commands -->
<!-- Example for OpenBao:
**Backend:** OpenBao
```bash
~/.openbao/start.sh           # bootstrap
export BAO_ADDR=http://127.0.0.1:8200
bao kv get -field=password <path>
```
-->

## 5. Testing Requirements
<!-- How to run tests, what must pass before commit -->

## 6. Project-Specific Constraints
<!-- Any project-specific hard rules -->
CODEBASERULES
  echo "  Created template — edit to match your project"
else
  echo "  codebase_rules.md already exists — skipping"
fi

# 4. Create AI_SKILLS/INDEX.md (if not exists)
echo "[4/7] Creating AI_SKILLS/INDEX.md..."
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

# 5. Create stub files
echo "[5/7] Creating stub files..."

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
  echo "- **Summary:** Precision-MOD v2.0.0 bootstrapped" >> "$REPO_ROOT/planning_journal.md"
  echo "- **Next:** Configure codebase_rules.md for this project" >> "$REPO_ROOT/planning_journal.md"
  echo "  Created planning_journal.md"
fi

# Create AGENTS.md if not exists
if [ ! -f "$REPO_ROOT/AGENTS.md" ]; then
  cat > "$REPO_ROOT/AGENTS.md" << 'AGENTSMD'
# Project Name

> **Owner:** Your Name
> **Language:** en

MANDATORY: At the start of every task, read `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`, `filetree.md`, and `AI_SKILLS/INDEX.md`.
If `pre_compact_task_progress.md` exists, read it first (before any other action), then read the rulebook, the active plan (if any), and `filetree.md`, delete `pre_compact_task_progress.md`, and continue.

## Precision-MOD

Rulebook at `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` (v2.0.0). Project rules at `AI_Guidelines/codebase_rules.md`.

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

# Create CLAUDE.md pointer if not exists
if [ ! -f "$REPO_ROOT/CLAUDE.md" ]; then
  cat > "$REPO_ROOT/CLAUDE.md" << 'CLAUDEMD'
# Claude Code — see AGENTS.md

All instructions in `AGENTS.md`. Read `AGENTS.md` at session start.
CLAUDEMD
  echo "  Created CLAUDE.md pointer"
fi

# 6. Update .gitignore
echo "[6/7] Updating .gitignore..."
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

# 7. Optional: Install hooks
echo "[7/7] Hooks..."
if [ "$WITH_HOOKS" = true ]; then
  # Copy git-safe hook
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
echo "  3. Copy session-save.md and session-load.md from upstream to .ai/commands/"
echo "  4. Run: git add AI_Guidelines/ AI_SKILLS/ AI_tasks/ .ai/ AGENTS.md CLAUDE.md filetree.md planning_journal.md"
if [ "$WITH_OBSIDIAN" = true ]; then
  echo "  5. Open this directory as an Obsidian vault"
  echo "  6. Install claude-code-mcp plugin in Obsidian"
fi
echo ""
echo "Done."
