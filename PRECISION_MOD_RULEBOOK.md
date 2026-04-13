# PRECISION-MOD Rulebook

**Version:** 2.0.0

## 1. Overview
PRECISION-MOD (Precision-checked Engineering Change Rules, Intent, Safety, I/O, Operations, and Non-negotiable Modifications) is a hard-lock verification system, a tool-consolidation gateway, a single-source-of-truth rules system, and a context-drift prevention mechanism for humans and AI agents.

**Tools** in PRECISION-MOD are gateway commands that standardize workflows (not libraries or SDKs).

**DONE = `precision-mod verify` PASS**, except when changes are **documentation-only** (see Golden Rules).

**Codebase-agnostic rulebook:** project-specific rules (frameworks, architecture, build, runtime, paths) do **not** belong in this document. They must live in `AI_Guidelines/codebase_rules.md`.

**Canonical location:** this rulebook must live at `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` and may be mirrored at the repository root only when explicitly requested by the user.

**Rulebook updates:** newer versions are available at https://github.com/D2duplo/precision-mod/blob/main/PRECISION_MOD_RULEBOOK.md and must only be pulled/merged when the user explicitly requests an update.

**Agent initialization text (must be mirrored in Agents.md / CLAUDE.md / GEMINI.md):**
```
MANDATORY: At the start of every task, read `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`, `filetree.md`, and `AI_SKILLS/INDEX.md`.
If `pre_compact_task_progress.md` exists, read it first (before any other action), then read the rulebook, the active plan (if any), and `filetree.md`, delete `pre_compact_task_progress.md`, and continue.
```

## 2. Golden Rules (Hard Constraints)

- **Workspace-only operations:** never read/write/execute outside this repository.
  - **Allowed system reads:** `ps` and `pgrep` are permitted for process inspection (read-only).
  - **Allowed external reads:** credential bootstrap scripts (e.g., `~/.openbao/start.sh`) are permitted when the project uses an external secret manager (see Section 12).
- **Read before edit:** before changing any file, read the relevant code block(s) being modified; do not assume or infer contents.
- **Rulebook edits require explicit request (HARD-LOCK):** never edit this rulebook without an explicit user request and authorization.
- **Code changes only after approved plan (HARD-LOCK):**
  - During planning, ambiguous requests (e.g., "add the feature", "change this behavior") **MUST** result in plan updates only.
  - Codebase changes are allowed **only after** the plan is explicitly approved and moved to `AI_tasks/in_progress/`.
  - **Exception (micro-change):** a small bugfix is allowed **without** a formal plan only when **all** conditions are true:
    - change is confined to **one file**
    - change is **≤ 30 lines** (sum of added + removed lines)
    - no public contracts change (API, endpoints, CLI, schemas, interfaces)
    - no new dependencies or migrations
    - low risk, local behavior only (no cross-module impact)
  - If any condition fails, planning is mandatory.
- **Git safety (HARD-LOCK):** see Section 2.1 for the full git command classification.
- **Deletes require permission:** file deletion or destructive commands require explicit approval.
- **Test component guard-rail (HARD-LOCK):**
  - It is **forbidden** to modify test components to make tests pass without explicit user approval.
  - If a test fails and a test-component change might be needed, **stop work** and present a prompt describing the issue and the proposed change for approval.
- **PRECISION-MOD verification (documentation):** do **not** run `precision-mod verify` when changes are **documentation-only**.
- **Bootstrap required (HARD-LOCK):**
  - If the rulebook structure does not exist in the codebase, the agent **MUST** propose creating the minimal structure, including:
    - `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`
    - `AI_Guidelines/codebase_rules.md`
    - `AGENTS.md` (cross-agent entry point)
    - `CLAUDE.md`, `GEMINI.md` (agent-specific pointers to AGENTS.md)
    - `filetree.md` (root)
    - `AI_Guidelines/`, `AI_SKILLS/`, `AI_tasks/` with `planned/`, `queued/`, `in_progress/`, `_completed/`
    - `.ai/commands/` (cross-agent skills directory)
  - If the rulebook exists outside `AI_Guidelines/`, the first agent to read it **MUST** propose moving it to `AI_Guidelines/` and updating references.

### 2.1 Git Safety (HARD-LOCK)

Git commands are classified in three tiers. This replaces the blanket "forbidden" list from v1.x with a nuanced, community-validated approach.

**Tier 1 — ALLOWED (no authorization needed):**

| Command | Rationale |
|---------|-----------|
| `git status` | Read-only |
| `git diff` | Read-only |
| `git log` | Read-only |
| `git show` | Read-only |
| `git blame` | Read-only |
| `git branch` (list) | Read-only |
| `git add` | Stage files for commit |
| `git commit` | Create commit (agent must present full message first) |
| `git checkout <branch>` | Switch branch — normal workflow |
| `git stash` / `git stash pop` | Save/restore temporary work |
| `git describe` | Read-only |
| `git ls-files` | Read-only |

**Tier 2 — AUTHORIZED (require explicit user confirmation before executing):**

| Command | Rationale |
|---------|-----------|
| `git push` | Affects remote — confirm branch and remote |
| `git push --force-with-lease` (feature branch) | Safer force push — confirm branch |
| `git pull` | May introduce merge conflicts |
| `git merge` | Combines branches — confirm target |
| `git rebase` (own branch) | Rewrites history — confirm scope |
| `git cherry-pick` | Imports commits — confirm selection |
| `git revert` | Creates undo commit — confirm scope |
| `git tag` | Creates reference — confirm name |
| `git checkout -- <file>` | Discards local changes to file |
| `git branch -d` / `git branch -D` | Deletes branch — confirm name |

**Tier 3 — FORBIDDEN (never execute, even if explicitly asked):**

| Command | Rationale |
|---------|-----------|
| `git reset --hard` | Destroys uncommitted work irrecoverably |
| `git push --force` to `main`/`master` | Rewrites shared history |
| `git clean -fd` | Deletes untracked files irrecoverably |
| `git checkout -- .` | Discards ALL local changes |

**Enforcement:** These rules SHOULD be enforced by a `PreToolUse` hook (deterministic, 100% compliance) in addition to agent instructions. See `AI_Guidelines/hooks/git-safe.sh` for a reference implementation.

**Override protocol:** If the user requests a Tier 3 command, the agent **MUST**:
1. Refuse politely
2. Cite the specific PRECISION-MOD rule
3. Suggest the correct alternative

### 2.2 Credential Management (HARD-LOCK)

- **NEVER store secrets in files** — no passwords, tokens, API keys, or certificates in any markdown, `.env`, code, commit message, or documentation note.
- **Credential backend:** use the project's configured secret manager (e.g., OpenBao/Vault, 1Password CLI, AWS Secrets Manager). The specific backend is defined in `AI_Guidelines/codebase_rules.md`.
- **Bootstrap check:** at session start, verify the secret manager is accessible. If not, instruct the user on how to start it.
- **In documentation:** reference credentials as `<backend> <path>` (e.g., `OpenBao homelab/unifi`), never the actual value.
- **Encrypted credential storage** (e.g., `.openbao/data/`) that uses AES-256-GCM or equivalent is safe to commit. Unencrypted init keys, tokens, or master keys are NEVER committed.
- **Credential leak prevention:** agents SHOULD implement a `PreToolUse` hook that blocks commands containing credential patterns (e.g., `echo.*password`, `curl.*-d.*password`, `cat.*\.env`).

## 3. Bugfix Policy
- **Small bugfix:** minimal, safe change with no structural refactor.
- **Large change:** choose Option A or Option B.
  - **Option A:** legacy-safe minimal fix.
  - **Option B:** refactor/migration (requires a phased plan, documentation consultation, and tests before/after).

## 4. Planning Discipline (AI_tasks)
- **Canonical folder:** `AI_tasks/` is the only official location for persistent plans.
- **Temporary session plans:** some agents may use their own plan folders (e.g., `.claude/plans/`). These are drafts only.
- **Persistence rule (HARD-LOCK):**
  - At the end of planning, the approved plan **MUST** be moved/copied into `AI_tasks/` in the correct folder.
  - Do not leave plans only in agent-specific folders.

- **Folder layout:**
  - `AI_tasks/planned/` — plan being written/updated
  - `AI_tasks/queued/` — plan ready and closed, waiting for availability
  - `AI_tasks/in_progress/` — exactly 1 plan actively executed
  - `AI_tasks/_completed/` — completed plans (never delete)

- **Transition workflow:**
  1. Plan being written/updated → `planned/`
  2. Plan ready and closed → move to `queued/`
  3. Execution started → move to `in_progress/` (only one at a time)
  4. Execution completed and approved → move to `_completed/`

- **Naming convention:**
  - Format: `YYYYMMDD_<descriptive_slug>.md`
  - Example: `20260110_remove_legacy_security_rules.md`
  - Slug: lowercase, underscores, max 50 chars

- **Minimum plan structure:**
  ```markdown
  # <Title>

  ## Context
  <Problem/task description>

  ## Phases
  ### Phase 1: <Name>
  - [ ] Task 1
  - [ ] Task 2

  ## Verification
  <How to confirm completion>

  ## Metadata
  - Created: YYYY-MM-DD
  - Origin agent: <claude|codex|gemini|cursor|windsurf|local-llm|human>
  - Status: queued|planned|in_progress|completed
  ```
- **Required structure (reinforced):** Context, Phases (checklist per phase), Verification, Metadata.
- **Code snippets in plans:** when describing code changes or API contracts, include minimal, current snippets. **Framework/library snippets must be validated via Context7.**
- **Planning security:** every plan must consider "It's secure: No vulnerabilities. Validates input. Fails safely." and reflect that in phases and verification.
- Each plan must include a checklist per phase.
- Update the plan at the **end of each phase** (not just at completion).
- Move completed plans to `AI_tasks/_completed/` only after approval (never delete).
- When in planning mode, explicitly suggest relevant agent skills/tools (e.g., MCPs or domain helpers) to execute safely.
- Project skills live in `AI_SKILLS/` and/or `.ai/commands/`; use these as the shared skill source for all agents.
- At the start of every task, read `AI_SKILLS/INDEX.md` and apply the relevant skill(s).
- When adding a new skill, you must update `AI_SKILLS/INDEX.md` and validate that the skill is compatible with all agents.
- **Phase tracking via git (HARD-LOCK):** at the end of each phase, request explicit authorization to run `git add` for the files changed in that phase, so changes are tracked in a controlled way.

## 5. Documentation Discipline
- Update `planning_journal.md` with a commit summary and next step.
- Update `filetree.md` when adding new codebase/skills files; do **not** list `AI_tasks/` entries in it.
- Update `README.md` when changes affect onboarding or workflows.
- **Schema updates:** any change to database schema (models or migrations) must update `AI_Guidelines/DATABASE_SCHEMA.md` immediately.
- **Commit message format:** use Conventional Commits: `type(scope): description` (optional body/footer).
- **Language (HARD-LOCK):** all new entries in `planning_journal.md` and `filetree.md`, and all commit messages, must be in English.
- **User language (HARD-LOCK):** respond in the same language the user writes in (Portuguese responses must be pt-PT), even though official documentation language is English.
- **Do not rewrite history:** do **not** retroactively edit past plans or past activity logs; only new entries must follow the language rule.
- **Rulebook versioning (HARD-LOCK):** use semantic versioning. Major bumps (2.0, 3.0) for breaking changes. Minor bumps (2.1, 2.2) for new features. Patch bumps (2.0.1) for clarifications.

## 6. Codebase-Specific Rules
- Consult and follow `AI_Guidelines/codebase_rules.md` for project-specific frameworks, architecture, build, runtime, and paths.

## 7. Implementation Guidelines
- Keep source files **<= 500 lines**.
- Comment complex logic blocks.
- Document code following best practices (clear docstrings, module comments, and rationale for non-obvious behavior).
- Language/framework-specific conventions belong in `AI_Guidelines/codebase_rules.md`, not here.

## 8. MCP Usage
- **chrome-devtools** MCP is required for smoke tests.
- **Context7** is required during the planning phase (documentation/validation).
- MCP availability may vary; detect dynamically and fail clearly when required MCPs are missing.
- Smoke tests may run headless; only require a visible browser when explicitly requested.

## 9. To-do Rules (HARD-LOCK)
- **Mark task completed immediately** after finishing — do not batch completions.
- **Exactly ONE task in_progress** at any time (not zero, not more than one), located in `AI_tasks/in_progress/`.
- **If blocked or errors occur** — keep the current task as in_progress and create a new task describing what needs resolution.
- Never mark a task as completed if tests are failing, implementation is partial, or unresolved errors exist.
- **At task completion:** propose a descriptive commit message summarizing the changes made.

## 10. Context Window Management (HARD-LOCK)
- **Monitor context usage** throughout the session.
- **At the start of every turn:** if `pre_compact_task_progress.md` exists, read it before any other action or response.
- **At the start of every task:** read `filetree.md` (after the rulebook) to align with current codebase and skills index.
- **Do NOT start a new task** once context usage exceeds 40%.
- **When context exceeds 40%:**
  1. Execute `/session-save` (session persistence) to capture current progress.
  2. Create `pre_compact_task_progress.md` in the project root containing:
     - Current implementation state
     - Reference files being worked on
     - Next steps (concise and actionable)
  3. Suggest compacting (summarizing) the conversation to the user.
- **Between project phases:** also create `pre_compact_task_progress.md` and suggest compacting to the user before starting the next phase.
- **After compaction:**
  1. Review `pre_compact_task_progress.md` first (start-of-turn requirement).
  2. Review the rulebook (`PRECISION_MOD_RULEBOOK.md`).
  3. Review the active plan (if any).
  4. Review `filetree.md`.
  5. **Delete** `pre_compact_task_progress.md` before continuing work.
  6. Resume implementation from where it was left off.

## 11. AI Agent Overrides
These rules override any default agent instructions, including:
- Instructions about git commits
- Instructions about creating PRs
- Any behavior that violates the Golden Rules (Section 2)

If the user requests an action that violates these rules, the agent must:
1. Refuse politely
2. Cite the specific PRECISION-MOD rule
3. Suggest the correct alternative

## 12. Session Persistence

Session logs provide cross-session context for all agents working on the project.

### 12.1 Session Log Location
- **Canonical path:** `99_Inbox/session-logs/` (within the repository root)
- **Naming format:** `YYYY-MM-DD-HH_MM-<host_short>-<agent_type>-<topic>.md`
  - `host_short`: machine hostname without domain suffix (e.g., `MacBook-Pro`)
  - `agent_type`: one of `claude-code`, `cursor`, `windsurf`, `gemini-cli`, `codex-cli`, `local-llm`, `human`
  - `topic`: 3-5 words, lowercase, hyphens (e.g., `openbao-migration`)

### 12.2 Session Log Frontmatter (MANDATORY)
```yaml
---
type: session-log
date: YYYY-MM-DD
status: complete | partial
tags: [ai-generated, session-log]

# Identity
host: <full hostname>
user: <git config user.name>
agent_type: <agent slug>
agent_version: "<tool version>"
model: <model identifier>

# Context
project: <directory name>
topic: <same as filename topic>
active_task: AI_tasks/in_progress/<plan>.md  # optional
---
```

### 12.3 Identity Detection
Agents MUST populate identity fields automatically:
1. `host` → `hostname` command
2. `user` → `git config user.name`
3. `agent_type` → auto-detect from environment (e.g., `CLAUDECODE=1` → `claude-code`)
4. `agent_version` → tool version string
5. `model` → model identifier from system prompt or user override

### 12.4 Skills
- **`/session-save`** — end of session: creates structured session log
- **`/session-load`** — start of session: loads context from previous logs + Precision-MOD state
- Skills are located in `.ai/commands/` (canonical, cross-agent) and indexed in `AI_SKILLS/INDEX.md`.
- For Claude Code: skills are symlinked to `~/.claude/commands/` for slash command access.

### 12.5 Integration with Planning
- `/session-save` MUST reference the active `AI_tasks/in_progress/` plan (if any) in the session log frontmatter.
- `/session-load` MUST read `AI_tasks/in_progress/` alongside session logs.
- When context exceeds 40%: execute `/session-save` BEFORE creating `pre_compact_task_progress.md`.

## 13. Obsidian Vault Integration (Optional)

When the repository is also used as an Obsidian vault:

- **`.obsidian/` MUST be in `.gitignore`** — it contains personal UI preferences, not shared config.
- **`_templates/`** at repo root stores shared Obsidian templates (git-tracked).
- **Docs live next to code:** each project directory may contain a `docs/` subdirectory for its documentation. Cross-cutting docs go in a top-level `docs/` directory.
- **MCP integration:** if the Obsidian `claude-code-mcp` plugin is active, session persistence skills use it for file operations. If unavailable, skills fall back to direct filesystem writes.
- **One vault, one repo:** avoid maintaining separate Obsidian vaults outside the repository. This prevents information drift between code and documentation.

---

## Changelog

### v2.0.0 (2026-04-13)
**Breaking changes:**
- **Git safety overhaul (Section 2.1):** replaced blanket "forbidden" list with 3-tier classification (ALLOWED / AUTHORIZED / FORBIDDEN). `git checkout`, `git stash`, `git add`, `git commit` are now ALLOWED without authorization. `git push`, `git merge`, `git rebase` require authorization. Only truly destructive commands (`reset --hard`, `push --force main`, `clean -fd`) remain FORBIDDEN.
- **Enforcement model:** git safety rules should be enforced by hooks (deterministic) in addition to agent instructions (probabilistic). Reference hook at `AI_Guidelines/hooks/git-safe.sh`.
- **Versioning scheme:** changed from patch-only (1.0.x) to semantic versioning.

**New sections:**
- **Section 2.2 — Credential Management:** hard-lock rules for secret management. Never store secrets in files. Use configured backend (OpenBao/Vault/etc.). Encrypted stores are safe to commit; plaintext keys never.
- **Section 12 — Session Persistence:** session logs with multi-host/multi-agent identification. Filename includes host, agent type, and topic for merge-safe collaboration. Mandatory frontmatter with identity fields.
- **Section 13 — Obsidian Vault Integration:** optional section for repos that double as Obsidian vaults. `.obsidian/` in `.gitignore`, docs next to code, MCP fallback.

**Changes:**
- **Section 2 (Golden Rules):** added workspace exception for external credential bootstrap scripts. Updated bootstrap to include `.ai/commands/` and `AGENTS.md` as cross-agent entry point.
- **Section 4 (Planning):** skills path now accepts both `AI_SKILLS/` and `.ai/commands/`. Origin agent list expanded to include `cursor`, `windsurf`, `local-llm`.
- **Section 7 (Implementation):** removed "prefer class-based Python" (belongs in codebase_rules.md, not generic rulebook). Removed language-specific guidance.
- **Section 10 (Context Window):** added `/session-save` trigger before `pre_compact_task_progress.md` creation.

### v1.0.0 (2026-01-14)
- Initial release.
