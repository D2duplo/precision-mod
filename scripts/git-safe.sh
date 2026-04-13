#!/usr/bin/env bash
# Precision-MOD — Git Safety Hook (PreToolUse)
# Enforces the 3-tier git command classification from PRECISION_MOD_RULEBOOK.md v2.0.0
#
# Usage in .claude/settings.json:
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{
#         "type": "command",
#         "command": "bash AI_Guidelines/hooks/git-safe.sh \"$TOOL_INPUT\""
#       }]
#     }]
#   }
# }
#
# Exit codes:
#   0 = allowed (Tier 1) or not a git command
#   2 = blocked (Tier 3 FORBIDDEN)
#
# Tier 2 (AUTHORIZED) commands are allowed through by this hook.
# The rulebook instructs agents to ask for confirmation — this hook
# does not block them because the user has already approved via the
# Claude Code permission prompt.

INPUT="$*"

# Not a git command — allow
if ! echo "$INPUT" | grep -qE '^\s*git\s|"git\s'; then
  exit 0
fi

# Extract the git subcommand
GIT_CMD=$(echo "$INPUT" | sed -E 's/.*git\s+//' | awk '{print $1}')

# --- Tier 3: FORBIDDEN (always block) ---

# git reset --hard
if echo "$INPUT" | grep -qE 'git\s+reset\s+--hard'; then
  echo '{"decision": "block", "reason": "BLOCKED by Precision-MOD: git reset --hard is FORBIDDEN (Tier 3). Destroys uncommitted work irrecoverably. Alternative: use git stash or git checkout -- <file>."}'
  exit 2
fi

# git push --force (without --force-with-lease) — FORBIDDEN on any branch
if echo "$INPUT" | grep -qE 'git\s+push\s+.*--force' && ! echo "$INPUT" | grep -qE '--force-with-lease'; then
  echo '{"decision": "block", "reason": "BLOCKED by Precision-MOD: git push --force is FORBIDDEN (Tier 3). Only --force-with-lease is allowed (Tier 2, feature branches only). Alternative: use git push --force-with-lease."}'
  exit 2
fi

# git clean -fd / -f
if echo "$INPUT" | grep -qE 'git\s+clean\s+-[a-z]*f'; then
  echo '{"decision": "block", "reason": "BLOCKED by Precision-MOD: git clean -f is FORBIDDEN (Tier 3). Deletes untracked files irrecoverably. Alternative: review with git clean -n (dry run) first, then delete manually."}'
  exit 2
fi

# git checkout -- . (discard ALL changes)
if echo "$INPUT" | grep -qE 'git\s+checkout\s+--\s+\.'; then
  echo '{"decision": "block", "reason": "BLOCKED by Precision-MOD: git checkout -- . is FORBIDDEN (Tier 3). Discards ALL local changes irrecoverably. Alternative: use git checkout -- <specific-file> for individual files."}'
  exit 2
fi

# git filter-branch (rewrites repository history)
if echo "$INPUT" | grep -qE 'git\s+filter-branch'; then
  echo '{"decision": "block", "reason": "BLOCKED by Precision-MOD: git filter-branch is FORBIDDEN (Tier 3). Rewrites repository history. Alternative: use git filter-repo (separate tool) with explicit user approval."}'
  exit 2
fi

# git restore . (discard ALL changes — modern equivalent of checkout -- .)
if echo "$INPUT" | grep -qE 'git\s+restore\s+\.'; then
  echo '{"decision": "block", "reason": "BLOCKED by Precision-MOD: git restore . is FORBIDDEN (Tier 3). Discards ALL local changes irrecoverably (modern equivalent of git checkout -- .). Alternative: use git restore <specific-file> for individual files."}'
  exit 2
fi

# --- All other git commands: allow (Tier 1 and Tier 2) ---
# Tier 2 commands (push, merge, rebase, etc.) are allowed through.
# The agent is instructed by the rulebook to ask the user for confirmation.
exit 0
