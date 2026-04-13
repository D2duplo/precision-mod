# /session-save — Save session context (multi-agent persistence)

Saves a structured session summary as a session log so that future sessions (from any agent) can resume context.

## Instructions

### 1. Detect agent identity

Before anything else, collect automatically:

1. **host** — run `hostname`
2. **host_short** — hostname without `.local` suffix (e.g., `MacBook-Pro`)
3. **user** — run `git config user.name`
4. **agent_type** — auto-detect:
   - If env `CLAUDECODE=1` → `claude-code`
   - If env `CURSOR_SESSION` exists → `cursor`
   - If env `WINDSURF` exists → `windsurf`
   - Otherwise, ask the user (options: `claude-code`, `cursor`, `windsurf`, `gemini-cli`, `codex-cli`, `local-llm`, `human`)
5. **agent_version** — tool version (e.g., `claude --version`, or env `CLAUDE_CODE_EXECPATH`)
6. **model** — self-identify from system prompt, or ask the user

### 2. Ask for categories and topic

- **Ask the user** which categories to preserve (use all if they say "everything"):
  - Decisions made
  - Learnings / Lessons learned
  - Files modified
  - Pending tasks
  - Errors and workarounds
  - Solutions applied

- **Ask for a topic** (3-5 words, lowercase, hyphens) or suggest one based on the work done.

### 3. Check Precision-MOD state (active task)

- Check if any file exists in `AI_tasks/in_progress/`.
- If found, read the plan and store the path for frontmatter (`active_task`).
- Add "## Active Task Progress" section in the log body with current phase summary.

### 4. Check creation context

- If the log is being created due to context window pressure (pre-compact), use `status: partial` instead of `complete`.

### 5. Create the session log

**Filename format:**
```
YYYY-MM-DD-HH_MM-<host_short>-<agent_type>-<topic>.md
```
Example: `2026-04-13-15_30-MacBook-Pro-claude-code-vyos-bgp-fix.md`

**Destination path:** `99_Inbox/session-logs/`

**Write method (in order of preference):**
1. Try `mcp__obsidian-vault__create` with path relative to vault root: `99_Inbox/session-logs/<filename>`
2. If MCP unavailable, write directly to filesystem: `<repo_root>/99_Inbox/session-logs/<filename>`

**Session log format** (follow exactly):

```markdown
---
type: session-log
date: YYYY-MM-DD
status: complete
tags: [ai-generated, session-log]

# Identity
host: <full hostname>
user: <git config user.name>
agent_type: <agent slug>
agent_version: "<tool version>"
model: <model identifier>

# Context
project: <working directory name>
topic: <same topic as filename>
active_task: AI_tasks/in_progress/<plan>.md
---

# Session: <topic>

## Quick Reference
- **Keywords:** <5-7 keywords for search>
- **Project:** <working directory>
- **Outcome:** <one sentence summary>
- **Duration:** short | medium | long

## Active Task Progress
> Current phase of plan, what was done, next step.
> (omit this section if no active_task)

## Decisions
| Decision | Rationale |
|----------|-----------|
| ... | ... |

## Key Learnings
- ...

## Solutions Applied
| Problem | Solution |
|---------|----------|
| ... | ... |

## Files Modified
- `path/to/file` — description of change
- ...

## Pending Tasks
- [ ] ...
- [ ] ...

## Errors and Workarounds
| Error | Workaround |
|-------|------------|
| ... | ... |

---
## Raw Session Notes
<free-form summary of what was discussed and done, for searchability>
```

### 6. Rules

- Only include sections the user selected (or all if they said "everything")
- **Quick Reference is MANDATORY** — it's what `/session-load` reads
- Be concise — status, decisions with rationale, file references
- **NEVER include credentials, tokens, or secrets**
- The `active_task` field only appears in frontmatter if a file exists in `AI_tasks/in_progress/`
- If `status: partial`, add note in Quick Reference: "Session interrupted due to context limit"

### 7. Confirm

After creating, confirm to user with:
- Full path of created file
- Method used (MCP or filesystem)
- Whether an active_task was detected
