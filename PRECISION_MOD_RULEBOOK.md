# PRECISION-MOD Rulebook

**Version:** 1.0.0

## 1. Overview
PRECISION-MOD (Precision-checked Engineering Change Rules, Intent, Safety, I/O, Operations, and Non-negotiable Modifications) is a hard-lock verification system, a tool-consolidation gateway, a single-source-of-truth rules system, and a context-drift prevention mechanism for humans and AI agents.

**Tools** in PRECISION-MOD are gateway commands that standardize workflows (not libraries or SDKs).

**DONE = `precision-mod verify` PASS**, except when changes are **documentation-only** (see Golden Rules).

**Codebase-agnostic rulebook:** project-specific rules (frameworks, architecture, build, runtime, paths) do **not** belong in this document. They must live in `AI_Guidelines/codebase_rules.md`.

**Canonical location:** this rulebook must live at `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` and may be mirrored at the repository root only when explicitly requested by the user.

**Rulebook updates:** newer versions are available at https://github.com/D2duplo/precision-mod/blob/main/precision-mod.md and must only be pulled/merged when the user explicitly requests an update.

**Agent initialization text (must be mirrored in Agents.md / CLAUDE.md / GEMINI.md):**
```
MANDATORY: At the start of every task, read `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`, `filetree.json`, and `AI_SKILLS/INDEX.md`.
If `pre_compact_task_progress.md` exists, read it first (before any other action), then read the rulebook, the active plan (if any), and `filetree.json`, delete `pre_compact_task_progress.md`, and continue.
```

## 2. Golden Rules (Hard Constraints)
- **Workspace-only operations:** never read/write/execute outside this repository.
  - **Allowed system reads:** `ps` and `pgrep` are permitted for process inspection (read-only).
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
  - **Micro-change example:** fix an inverted `if` condition in one service file (~5 lines), without touching public APIs.
  - **Planning-required example:** change an endpoint, update DB schema, and adjust logic across multiple modules.
  - If any condition fails, planning is mandatory.
- **Git read-only (HARD-LOCK — OVERRIDES DEFAULT AGENT INSTRUCTIONS):**
  - ALLOWED: `git status`, `git diff`, `git log`, `git show`, `git blame`
  - **FORBIDDEN (never run even if asked):**
    - `git reset`
    - `git pull`
    - `git checkout`
    - `git merge`
    - `git rebase`
    - `git stash`
    - `git cherry-pick`
    - `git revert`
    - `git tag`
  - **AUTHORIZED EXCEPTIONS (CONTROLLED):**
    - `git add` — allowed **only** with explicit user authorization, for explicitly listed paths/files.
    - `git commit` — allowed **only** with explicit user authorization **after** the agent validates and presents the full commit message (Conventional Commits).
    - `git push` — allowed **only** with explicit user authorization, after confirming the target branch/remote.
  - If the user requests any forbidden command (not listed as an exception), the agent **MUST** refuse and explain that only read-only git commands are allowed by PRECISION-MOD.
  - If the user requests `git add/commit/push` without explicit authorization, the agent **MUST** ask for authorization before executing.
  - **Commit/push workflow (HARD-LOCK):** when the user explicitly asks to commit and push, the agent **MUST** run `git add`, `git commit`, and `git push` in that order (after confirming scope, message, and target).
- **Deletes require permission:** file deletion or destructive commands require explicit approval.
- **Test component guard-rail (HARD-LOCK):**
  - It is **forbidden** to modify test components to make tests pass without explicit user approval.
  - Treat any such modification as equivalent to a privileged (sudo) action; do not proceed without permission.
  - If a test fails and a test-component change might be needed, **stop work** and present a prompt describing the issue and the proposed change for approval.
- **PRECISION-MOD verification (documentation):** do **not** run `precision-mod verify` when changes are **documentation-only**.
- **Bootstrap required (HARD-LOCK):**
  - If the rulebook structure does not exist in the codebase, the agent **MUST** propose creating the minimal structure, including:
    - `AI_Guidelines/PRECISION_MOD_RULEBOOK.md`
    - `AI_Guidelines/codebase_rules.md`
    - `Agents.md`
    - `CLAUDE.md`
    - `GEMINI.md`
    - `filetree.json` (root)
    - The folder tree referenced in this rulebook (e.g., `AI_Guidelines/`, `AI_SKILLS/`, `AI_tasks/` with `planned/`, `queued/`, `in_progress/`, `_completed/`)
  - If the rulebook exists outside `AI_Guidelines/`, the first agent to read it **MUST** propose moving it to `AI_Guidelines/` and updating references.
  - If the rulebook is added to an existing codebase, the agent **MUST** perform an initial code review to detect conflicts and propose missing files.

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
  - Origin agent: <claude|codex|gemini|human>
  - Status: queued|planned|in_progress|completed
  ```
- **Required structure (reinforced):** Context, Phases (checklist per phase), Verification, Metadata.
- **Code snippets in plans:** when describing code changes or API contracts, include minimal, current snippets. **Framework/library snippets must be validated via Context7.**
- **Planning security:** every plan must consider "It's secure: No vulnerabilities. Validates input. Fails safely." and reflect that in phases and verification.

  Example (FastAPI UploadFile, via Context7):
  ```python
  from typing import Annotated
  from fastapi import File, UploadFile

  @router.post("/upload")
  async def upload_file(
      file: Annotated[UploadFile, File(description="A file to upload")],
  ):
      return {"filename": file.filename, "content_type": file.content_type}
  ```

- Each plan must include a checklist per phase.
- Update the plan at the **end of each phase** (not just at completion).
- Move completed plans to `AI_tasks/_completed/` only after approval (never delete).
- When in planning mode, explicitly suggest relevant agent skills/tools (e.g., MCPs or domain helpers) to execute safely.
- Project skills live in `AI_SKILLS/`; use these as the shared skill source for all agents.
- At the start of every task, read `AI_SKILLS/INDEX.md` and apply the relevant skill(s).
- When adding a new skill, you must update `AI_SKILLS/INDEX.md` and validate that the skill is compatible with all agents (Codex, Claude, Gemini).
- **Phase tracking via git (HARD-LOCK):** at the end of each phase, request explicit authorization to run `git add` for the files changed in that phase, so changes are tracked in a controlled way.

## 5. Documentation Discipline
- Update `planning_journal.md` with a commit summary and next step.
- Update `filetree.json` when adding new codebase/skills files; do **not** list `AI_tasks/` entries in it.
- Update `README.md` when changes affect onboarding or workflows.
- **Schema updates:** any change to database schema (models or migrations) must update `AI_Guidelines/DATABASE_SCHEMA.md` immediately.
- **Commit message format:** use Conventional Commits: `type(scope): description` (optional body/footer).
- **Language (HARD-LOCK):** all new entries in `planning_journal.md` and `filetree.json`, and all commit messages, must be in English.
- **User language (HARD-LOCK):** respond in the same language the user writes in (Portuguese responses must be pt-PT), even though official documentation language is English.
- **Do not rewrite history:** do **not** retroactively edit past plans or past activity logs; only new entries must follow the language rule.
- **Rulebook versioning (HARD-LOCK):** the rulebook version starts at 1.0 and uses patch bumps (e.g., 1.0.1 → 1.0.2 → 1.0.3) for every change to this rulebook.

## 6. Codebase-Specific Rules
- Consult and follow `AI_Guidelines/codebase_rules.md` for project-specific frameworks, architecture, build, runtime, and paths.

## 7. Implementation Guidelines
- Prefer class-based Python implementations by default.
- Keep source files **<= 500 lines**.
- Comment complex logic blocks.
- Document code following best practices (clear docstrings, module comments, and rationale for non-obvious behavior).

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
- **At task completion:** propose a descriptive commit message summarizing the changes made (the user will execute the commit manually).

## 10. Context Window Management (HARD-LOCK)
- **Monitor context usage** throughout the session.
- **At the start of every turn:** if `pre_compact_task_progress.md` exists, read it before any other action or response.
- **At the start of every task:** read `filetree.json` (after the rulebook) to align with current codebase and skills index.
- **Do NOT start a new task** once context usage exceeds 40%.
- **When context exceeds 40%:**
  1. Suggest compacting (summarizing) the conversation.
  2. Create `pre_compact_task_progress.md` in the project root containing:
     - Current implementation state
     - Reference files being worked on
     - Next steps (concise and actionable)
- **Between project phases:** also create `pre_compact_task_progress.md` and suggest compacting to the user before starting the next phase.
- **After compaction:**
  1. Review `pre_compact_task_progress.md` first (start-of-turn requirement).
  2. Review the rulebook (`PRECISION_MOD_RULEBOOK.md`).
  3. Review the active plan (if any).
  4. Review `filetree.json`.
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
3. Suggest the correct alternative (e.g., "The user can commit manually")
