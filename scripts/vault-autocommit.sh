#!/usr/bin/env bash
# Precision-MOD — Vault Auto-Commit
# Automatically commits session logs and documentation changes at regular intervals.
#
# Usage:
#   bash AI_Guidelines/precision-mod-upstream/scripts/vault-autocommit.sh [--interval 900] [--daemon]
#
# Options:
#   --interval N   Commit interval in seconds (default: 900 = 15 minutes)
#   --daemon       Run as background daemon (detached from terminal)
#   --once         Run once and exit (useful for cron/launchd)
#   --dry-run      Show what would be committed without doing it
#
# What gets auto-committed:
#   - 99_Inbox/session-logs/*.md
#   - planning_journal.md
#   - AI_tasks/**/*.md
#   - filetree.md
#   - docs/**/*.md (project documentation)
#
# What is NEVER auto-committed:
#   - Code files (*.py, *.js, *.php, etc.)
#   - Configuration files (.env, *.json, *.yaml)
#   - The rulebook itself
#   - Anything outside the tracked patterns

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || exit 1)"
INTERVAL=900
DAEMON=false
ONCE=false
DRY_RUN=false
LOCKFILE="$REPO_ROOT/.vault-autocommit.lock"

while [ $# -gt 0 ]; do
  case "$1" in
    --interval) shift; INTERVAL="${1:-900}" ;;
    --daemon)   DAEMON=true ;;
    --once)     ONCE=true ;;
    --dry-run)  DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [--interval N] [--daemon] [--once] [--dry-run]"
      exit 0
      ;;
  esac
  shift
done

# Patterns to auto-commit (documentation and session data only)
AUTOCOMMIT_PATTERNS=(
  "99_Inbox/session-logs/*.md"
  "planning_journal.md"
  "AI_tasks/**/*.md"
  "filetree.md"
  "*/docs/**/*.md"
  "docs/**/*.md"
  "_templates/*.md"
)

do_autocommit() {
  cd "$REPO_ROOT"

  # Collect files matching patterns
  local files_to_add=()
  for pattern in "${AUTOCOMMIT_PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
      files_to_add+=("$file")
    done < <(find . -path "./$pattern" -newer "$LOCKFILE" -print0 2>/dev/null || true)
  done

  # Also check git status for new/modified files matching patterns
  local staged=()
  while IFS= read -r line; do
    local status="${line:0:2}"
    local file="${line:3}"
    for pattern in "${AUTOCOMMIT_PATTERNS[@]}"; do
      # Simple glob match
      if [[ "$file" == $pattern ]]; then
        staged+=("$file")
        break
      fi
    done
  done < <(git status --porcelain 2>/dev/null || true)

  # Merge and deduplicate
  local all_files=()
  for f in "${files_to_add[@]}" "${staged[@]}"; do
    # Remove leading ./
    f="${f#./}"
    # Check not already in list
    local found=false
    for existing in "${all_files[@]+"${all_files[@]}"}"; do
      if [ "$existing" = "$f" ]; then found=true; break; fi
    done
    if [ "$found" = false ] && [ -f "$f" ]; then
      all_files+=("$f")
    fi
  done

  if [ ${#all_files[@]} -eq 0 ]; then
    return 0
  fi

  local host_short
  host_short="$(hostname -s 2>/dev/null || hostname | sed 's/\.local$//')"
  local timestamp
  timestamp="$(date +%Y-%m-%d\ %H:%M)"

  if [ "$DRY_RUN" = true ]; then
    echo "[$timestamp] Would auto-commit ${#all_files[@]} file(s):"
    printf "  %s\n" "${all_files[@]}"
    return 0
  fi

  # Stage and commit
  git add "${all_files[@]}"

  # Check if there are actually staged changes
  if git diff --cached --quiet; then
    return 0
  fi

  git commit -m "docs(vault): auto-commit session data [$host_short]

Auto-committed ${#all_files[@]} file(s) by vault-autocommit.sh
Host: $host_short
Time: $timestamp"

  echo "[$timestamp] Auto-committed ${#all_files[@]} file(s)"

  # Update lockfile timestamp
  touch "$LOCKFILE"
}

# Initialize lockfile
touch "$LOCKFILE"

if [ "$ONCE" = true ]; then
  do_autocommit
  exit 0
fi

if [ "$DAEMON" = true ]; then
  echo "Starting vault auto-commit daemon (interval: ${INTERVAL}s)"
  echo "PID: $$"
  echo "$$" > "$REPO_ROOT/.vault-autocommit.pid"

  trap 'rm -f "$REPO_ROOT/.vault-autocommit.pid" "$LOCKFILE"; exit 0' INT TERM

  while true; do
    do_autocommit || true
    sleep "$INTERVAL"
  done
else
  echo "Running vault auto-commit (interval: ${INTERVAL}s)"
  echo "Press Ctrl+C to stop"
  echo ""

  trap 'rm -f "$LOCKFILE"; echo ""; echo "Stopped."; exit 0' INT TERM

  while true; do
    do_autocommit || true
    sleep "$INTERVAL"
  done
fi
