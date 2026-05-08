#!/usr/bin/env bash
# Precision-MOD — Obsidian Vault Integration Setup
# Configures the repository as an Obsidian vault with MCP integration for AI agents.
#
# Usage: bash AI_Guidelines/precision-mod-upstream/scripts/setup-obsidian.sh [--port 22360] [--mcp-name obsidian-vault]
#
# Prerequisites:
#   - Obsidian installed (https://obsidian.md)
#   - claude-code-mcp plugin (https://github.com/iansinnott/obsidian-claude-code-mcp)
#   - Claude Code CLI (for MCP registration)

set -euo pipefail

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
MCP_PORT=22360
MCP_NAME="obsidian-vault"

while [ $# -gt 0 ]; do
  case "$1" in
    --port)      shift; MCP_PORT="${1:-22360}" ;;
    --mcp-name)  shift; MCP_NAME="${1:-obsidian-vault}" ;;
    --help|-h)
      echo "Usage: $0 [--port PORT] [--mcp-name NAME]"
      echo ""
      echo "  --port PORT       MCP server port (default: 22360)"
      echo "  --mcp-name NAME   MCP server name in Claude (default: obsidian-vault)"
      exit 0
      ;;
  esac
  shift
done

echo "=== Precision-MOD — Obsidian Vault Setup ==="
echo "Repo root: $REPO_ROOT"
echo "MCP port:  $MCP_PORT"
echo "MCP name:  $MCP_NAME"
echo ""

# 1. Ensure .obsidian/ in .gitignore
echo "[1/6] Checking .gitignore..."
if ! grep -qF ".obsidian/" "$REPO_ROOT/.gitignore" 2>/dev/null; then
  echo ".obsidian/" >> "$REPO_ROOT/.gitignore"
  echo "  Added .obsidian/ to .gitignore"
else
  echo "  .obsidian/ already in .gitignore"
fi

# 2. Create vault directories
echo "[2/6] Creating vault directories..."
mkdir -p "$REPO_ROOT/99_Inbox/session-logs"
mkdir -p "$REPO_ROOT/_templates"
mkdir -p "$REPO_ROOT/docs"
echo "  Created 99_Inbox/session-logs/, _templates/, docs/"

# 3. Create session-log template
echo "[3/6] Creating session-log template..."
if [ ! -f "$REPO_ROOT/_templates/session-log.md" ]; then
  cat > "$REPO_ROOT/_templates/session-log.md" << 'TEMPLATE'
---
type: session-log
date: {{date:YYYY-MM-DD}}
status: complete
tags: [ai-generated, session-log]

# Identity
host:
user:
agent_type:
agent_version: ""
model:

# Context
project:
topic:
active_task:
---

# Session: {{title}}

## Quick Reference
- **Keywords:**
- **Project:**
- **Outcome:**
- **Duration:** short | medium | long

## Decisions
| Decision | Rationale |
|----------|-----------|
| ... | ... |

## Key Learnings
- ...

## Files Modified
- `path/to/file` — description

## Pending Tasks
- [ ] ...

---
## Raw Session Notes

TEMPLATE
  echo "  Created _templates/session-log.md"
else
  echo "  Template already exists"
fi

# 4. Check Obsidian installation
echo "[4/6] Checking Obsidian..."
if [ -d "/Applications/Obsidian.app" ] || [ -d "$HOME/Applications/Obsidian.app" ]; then
  echo "  Obsidian is installed"
else
  echo "  WARNING: Obsidian not found in /Applications/"
  echo "  Install from https://obsidian.md before continuing"
fi

# 5. Check plugin
echo "[5/6] Checking claude-code-mcp plugin..."
PLUGIN_DIR="$REPO_ROOT/.obsidian/plugins/claude-code-mcp"
if [ -d "$PLUGIN_DIR" ]; then
  echo "  Plugin installed"
  # Configure port
  if [ -f "$PLUGIN_DIR/data.json" ]; then
    echo "  data.json exists — verify mcpHttpPort is $MCP_PORT"
  else
    echo "  Creating data.json with port $MCP_PORT..."
    cat > "$PLUGIN_DIR/data.json" << PLUGINCONF
{
  "mcpHttpPort": $MCP_PORT,
  "enableHttpServer": true,
  "enableWebSocketServer": true
}
PLUGINCONF
  fi
else
  echo "  Plugin NOT installed."
  echo "  To install:"
  echo "    1. Open this directory as an Obsidian vault"
  echo "    2. Settings → Community Plugins → Browse → search 'Claude Code MCP'"
  echo "    3. Install and enable"
  echo "    4. Set HTTP port to $MCP_PORT in plugin settings"
  echo "    5. Re-run this script to verify"
fi

# 6. Register MCP with Claude Code
echo "[6/6] MCP registration..."
if command -v claude &>/dev/null; then
  echo "  Claude Code CLI found"
  echo ""
  echo "  To register the MCP server, run:"
  echo "    claude mcp add --transport sse --scope user $MCP_NAME http://localhost:$MCP_PORT/sse"
  echo ""
  echo "  To remove an old registration:"
  echo "    claude mcp remove <old-name>"
else
  echo "  Claude Code CLI not found — install from https://claude.ai/code"
  echo "  After installing, register MCP:"
  echo "    claude mcp add --transport sse --scope user $MCP_NAME http://localhost:$MCP_PORT/sse"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Open $REPO_ROOT as an Obsidian vault (File → Open Folder as Vault)"
echo "  2. Enable the claude-code-mcp community plugin"
echo "  3. Set port to $MCP_PORT in plugin settings"
echo "  4. Register MCP: claude mcp add --transport sse --scope user $MCP_NAME http://localhost:$MCP_PORT/sse"
echo "  5. Verify: start Claude Code and run /mcp to check connection"
echo ""
echo "Optional: Set up auto-commit for session logs:"
echo "  bash AI_Guidelines/precision-mod-upstream/scripts/vault-autocommit.sh --daemon --interval 900"
echo ""
echo "Optional: Set up vault auto-commit via launchd (macOS):"
echo "  See AI_INSTALL.md Section 9 for launchd plist template"
