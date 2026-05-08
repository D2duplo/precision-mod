# /session-load — Load context from previous sessions

Rebuilds the working context by reading state files, AGENTS.md, and the latest session logs.

## Arguments (optional)
- `/session-load` — loads last 3 session logs
- `/session-load 5` — loads last 5 session logs
- `/session-load auth` — loads last 3 + all matching "auth" in name/content
- `/session-load 10 migration` — loads last 10 + matching "migration"

## Instructions

### Step 1 — Check pre_compact (Precision-MOD)
If `pre_compact_task_progress.md` exists at the repo root, read it FIRST before anything else. This file has absolute priority — it contains the state of the task that was in progress before context compaction.

### Step 2 — Read AGENTS.md
Read `AGENTS.md` (repo root) for:
- Project structure
- Rules (especially credential management)
- Workflow and conventions

### Step 3 — Read Precision-MOD state
1. Read `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` — internalize constraints and operational rules
2. Read `filetree.md` — codebase index
3. Read `AI_SKILLS/INDEX.md` — available skills
4. Check `AI_tasks/in_progress/` — if active plans exist, read the most recent one

### Step 4 — Verify credential manager
```bash
export BAO_ADDR=http://127.0.0.1:8200
bao status 2>/dev/null | head -3
```
If sealed or not running, warn the user: "Credential manager is not active. Run `~/.openbao/start.sh` to start."

Note: the specific credential manager command is project-dependent. Check `AI_Guidelines/codebase_rules.md` for the configured backend.

### Step 5 — List session logs
List files in `99_Inbox/session-logs/` (relative to repo root) ordered by date (most recent first).

Try Obsidian MCP `mcp__obsidian-vault__get_workspace_files` first. Fallback to filesystem:
```bash
ls -1t 99_Inbox/session-logs/*.md 2>/dev/null | head -N
```

### Step 6 — Read session logs (Quick Reference only)
For each session log (up to N files):
1. Read the file
2. Extract ONLY from the start to `## Raw Session Notes` (or end of file if section doesn't exist)
3. Skip raw content — too large for context
4. Extract from frontmatter: `agent_type` and `model` — so user knows which agent did what

If a keyword was passed (e.g., `/session-load auth`), in addition to the last N:
- Search filenames and Quick Reference content for matches
- Include those additional logs

### Step 7 — Present summary

```
## Context loaded

**AGENTS.md:** ✓
**Precision-MOD:** ✓ v2.1.0
**Credential manager:** ✓ running | ⚠️ sealed | ✗ not running
**Active plan:** AI_tasks/in_progress/20260413_xxx.md (Phase 2/3) | None
**Session logs:** N found, M loaded

### Recent sessions:
1. **2026-04-13 14:30 — openbao-migration** (MacBook-Pro / claude-code / claude-opus-4-6)
   Outcome: ...
   Pending: ...

2. **2026-04-12 22:10 — mss-scope-validation** (MacBook-Pro / claude-code / claude-opus-4-6)
   Outcome: ...

### Pending tasks (aggregated):
- [ ] ...

Ready to continue.
```

### Rules:
- Be fast — don't read unnecessary files
- Quick Reference is designed for AI scanning — read only that section
- NEVER show credentials — reference as the configured backend path (e.g., "OpenBao homelab/<path>")
- If no session logs found: "No session logs found."
- If keyword match returns >10 results, show only the 5 most recent
