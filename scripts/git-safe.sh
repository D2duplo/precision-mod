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
  echo "BLOCKED by Precision-MOD: 'git reset --hard' is FORBIDDEN (Tier 3)."
  echo "This command destroys uncommitted work irrecoverably."
  echo "Alternative: use 'git stash' to save work, or 'git checkout -- <file>' for specific files."
  exit 2
fi

# git push --force to main/master (but allow --force-with-lease on feature branches)
if echo "$INPUT" | grep -qE 'git\s+push\s+.*--force' && ! echo "$INPUT" | grep -qE '--force-with-lease'; then
  # Check if pushing to main/master
  if echo "$INPUT" | grep -qE '(main|master)'; then
    echo "BLOCKED by Precision-MOD: 'git push --force' to main/master is FORBIDDEN (Tier 3)."
    echo "This rewrites shared history and can cause data loss for all collaborators."
    echo "Alternative: create a revert commit with 'git revert'."
    exit 2
  fi
fi

# git clean -fd / -f
if echo "$INPUT" | grep -qE 'git\s+clean\s+-[a-z]*f'; then
  echo "BLOCKED by Precision-MOD: 'git clean -f' is FORBIDDEN (Tier 3)."
  echo "This deletes untracked files irrecoverably."
  echo "Alternative: review files with 'git clean -n' (dry run) first, then delete manually."
  exit 2
fi

# git checkout -- . (discard ALL changes)
if echo "$INPUT" | grep -qE 'git\s+checkout\s+--\s+\.'; then
  echo "BLOCKED by Precision-MOD: 'git checkout -- .' is FORBIDDEN (Tier 3)."
  echo "This discards ALL local changes irrecoverably."
  echo "Alternative: use 'git checkout -- <specific-file>' for individual files."
  exit 2
fi

# --- All other git commands: allow (Tier 1 and Tier 2) ---
# Tier 2 commands (push, merge, rebase, etc.) are allowed through.
# The agent is instructed by the rulebook to ask the user for confirmation.
exit 0
