# PRECISION-MOD Rulebook

**Version:** 2.2.1

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
  - **Allowed external reads:** credential bootstrap scripts in the user's home directory (e.g., `~/.openbao/start.sh`, `~/.config/op/`) are permitted when the project uses an external secret manager (see Section 2.2).
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
| `git restore .` | Discards ALL local changes (modern equivalent of checkout -- .) |
| `git filter-branch` | Rewrites repository history |

**Enforcement:** These rules SHOULD be enforced by a `PreToolUse` hook (deterministic, 100% compliance) in addition to agent instructions. See `AI_Guidelines/hooks/git-safe.sh` for a reference implementation.

**Override protocol:** If the user requests a Tier 3 command, the agent **MUST**:
1. Refuse politely
2. Cite the specific PRECISION-MOD rule
3. Suggest the correct alternative

### 2.2 Credential Management

Applies only to projects that handle secrets (passwords, tokens, API keys, certificates). Projects that do not store credentials may skip this section.

- **HARD-LOCK — No plaintext secrets in tracked files:** never store passwords, tokens, API keys, or certificates in any markdown, code, commit message, or documentation note that is tracked by git or shared with collaborators. `.env` files containing real secrets must be in `.gitignore`.
- **Backend choice is OPTIONAL and project-specific.** Pick whatever fits the project's threat model and operational constraints. Document the choice (and the bootstrap/access commands) in `AI_Guidelines/codebase_rules.md`. Common options:

  | Backend | When it fits |
  |---|---|
  | OpenBao (recommended reference) | Self-hosted, offline-capable, file-based vault; encrypted blob safe to commit. Setup script and migration tool included — see `docs/credential-management.md`. |
  | HashiCorp Vault | Existing infra, multi-user policies. |
  | 1Password CLI / Bitwarden CLI | Personal projects or small teams already using these tools. |
  | AWS / GCP / Azure Secrets Manager | Cloud-native deployments. |
  | System keychain (macOS Keychain, GNOME Keyring, libsecret) + env vars | Single-developer setups, no team sharing. |
  | `.env` files in `.gitignore` (untracked) | Quick prototypes only, with team awareness of the risks. |

- **In documentation:** reference credentials by their location, never the actual value. Examples: `OpenBao homelab/unifi`, `1Password "Eng/Prod DB"`, `aws-sm:project/api-key`, `keychain://my-service`.
- **Credential leak prevention (RECOMMENDED):** agents MAY implement a `PreToolUse` hook that blocks commands containing credential patterns (e.g., `echo.*password`, `curl.*-d.*password`, `cat.*\.env`). Highly recommended when an agent is allowed to commit or push.
- **Migration from plaintext:** if an existing codebase has hardcoded credentials, scan and migrate them. For OpenBao adopters, `scripts/migrate-credentials.sh` automates this — see `docs/credential-management.md`. For other backends, follow the equivalent flow.
- **OpenBao setup (optional):** run `scripts/setup-openbao.sh` only if you have chosen OpenBao as the backend. The default install path does not require it.

### 2.3 Production Boundary

- **HARD-LOCK — Explicit, scoped authorization for production:** the agent MUST NOT apply, deploy, or trigger any change against a production-flagged target (production database, production deploy pipeline, published release, irreversible write against shared infrastructure, outbound message to real users) without an explicit, direct authorization that names the action and the target.
- **Authorization is per-action and per-target.** A "yes" granted for one production action does not extend to adjacent actions, even when they appear in the same workflow. The agent MUST NOT infer production approval from:
  - a non-specific affirmative (e.g., "sim", "ok", "go ahead") given in response to a multi-part prompt
  - approval of a planning step (which authorizes planning, not execution)
  - approval of a non-production action of the same shape (e.g., dev-environment success does not authorize prod)
- **No bundling (HARD-LOCK):** the agent MUST NOT bundle a production-flagged action with non-production actions in a single confirmation prompt. Production actions MUST be confirmed in isolation, so a single "yes" cannot be misinterpreted as authorizing the prod component of a multi-part request.
- **Define "production-flagged" in `codebase_rules.md`.** Each project enumerates which environments, scripts, services, and credentials are production-flagged. The rulebook does not prescribe a list.
- **Reversibility test:** when in doubt about whether an action is production-bound, ask whether it is reversible within the project's own controls (revert commit, drop table, kill process). If reversibility depends on a backup, an external party, or has a non-zero blast radius beyond the workspace, treat as production-flagged and require authorization.
- **Override protocol:** if the agent receives a production-flagged request without explicit, scoped authorization, the agent MUST:
  1. Pause execution
  2. Restate the action and target in a single sentence
  3. Request explicit authorization for that specific action and target
  4. Proceed only after the user confirms in plain terms (not a one-word reply to a multi-part prompt)

### 2.4 Sensitive Data Handling

- **HARD-LOCK — No sensitive data in tracked artefacts:** sensitive data MUST NOT appear in any artefact tracked by git or shared with collaborators (plans, commits, commit messages, documentation, session logs, test fixtures committed to the repo, screenshots committed to the repo, error reports pasted into bug reports). Reference sensitive data by location, never by value.
- **What counts as sensitive is project-specific.** Define the categories in `AI_Guidelines/codebase_rules.md`. Common categories include personal identifiers, financial identifiers, internal operational data, and credentials (credentials are also covered by Section 2.2).
- **Anonymization in tracked artefacts:** when sensitive data must be referenced for context (e.g., reproducing a bug), the agent MUST replace the value with a placeholder defined in `codebase_rules.md`. Examples of placeholder schemes a project might adopt: `[PERSON]`, `[ID]`, `[ACCOUNT]`, masked digits (`1234*****`), or location pointers (`record #N in table T`).
- **Logs and untracked artefacts** may contain sensitive data by necessity. They MUST be in `.gitignore` and MUST NOT be copied into tracked artefacts without anonymization.
- **Cross-reference:** Section 2.2 governs credentials specifically. This subsection governs all other sensitive data.

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
- **Mandatory tooling wrappers (HARD-LOCK):** when the project provides a wrapper script or command for a privileged or risky operation (database access, deployment, secret retrieval, log inspection, container exec, infrastructure changes), the agent MUST invoke the wrapper instead of the underlying CLI directly. Wrappers and their scopes are documented in `AI_Guidelines/codebase_rules.md`. The rulebook does not prescribe specific wrappers; it enforces the principle that, where one exists, it is the only sanctioned entry point.
- **Wrapper escape valve:** if the wrapper does not support the required operation, is broken, or is itself the artefact under modification, the agent MUST notify the user, state the gap, and request explicit authorization before invoking the underlying CLI as a fallback. Falling through silently is forbidden.

## 8. MCP Usage
- **chrome-devtools** MCP is recommended for smoke tests when available. Configure in `AI_Guidelines/codebase_rules.md` per project.
- **Context7** is recommended during the planning phase (documentation/validation) when available. Configure in `AI_Guidelines/codebase_rules.md` per project.
- MCP availability may vary; detect dynamically and degrade gracefully when MCPs are unavailable.
- Smoke tests may run headless; only require a visible browser when explicitly requested.

## 9. To-do Rules (HARD-LOCK)
- **Mark task completed immediately** after finishing — do not batch completions.
- **Exactly ONE task in_progress** at any time (not zero, not more than one), located in `AI_tasks/in_progress/`.
- **If blocked or errors occur** — keep the current task as in_progress and create a new task describing what needs resolution.
- Never mark a task as completed if tests are failing, implementation is partial, or unresolved errors exist.
- **Verification gate (HARD-LOCK):** every task MUST declare its verification gate before being marked completed. The gate is the concrete, reproducible check that proves the work is done.
  - **State-changing tasks** (code changes, infrastructure changes, deployments, data migrations) declare a concrete gate: test suite name, lint command, manual smoke step, peer review, deployment health check, or equivalent.
  - **Investigative or read-only tasks** (root-cause analysis, code reading, hypothesis checking) declare an *exit criterion* instead: the question answered, the hypothesis confirmed or refuted, the artefact produced (note, finding, recommendation).
  - **Plan-driven tasks:** the gate IS the plan's `## Verification` section (Section 4). No separate declaration needed.
  - **Ad-hoc tasks:** defaults are declared in `codebase_rules.md`. If no default exists for the task type, the agent MUST propose a gate before starting work.
  - Marking a task completed without running the declared gate (or recording the exit-criterion outcome) is forbidden, even if the agent is confident the work is correct.
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

## 14. Cross-Repository Impact

When a change in this repository can affect a sibling repository (deployment scripts, shared libraries, infrastructure configuration, dependent services, generated clients, schema consumers), the agent MUST notify the user before completing the task.

### 14.1 Notification Format

```
⚠️ CROSS-REPO IMPACT: <component changed>
Sibling repository: <repo name or path>
Reason: <why this affects the sibling>
Action required: <what the user should verify or update in the sibling>
```

This is a chat-time signal to the user before marking the task completed (Section 9). It is not required to appear in commit messages or tracked artefacts; it is a conversational guard-rail, not a metadata marker.

### 14.2 Detecting Cross-Repo Impact

- Each project documents its sibling repositories and their synchronization points in `AI_Guidelines/codebase_rules.md` (file paths, configuration variables, schema files, API contracts).
- The agent MUST consult this list before completing any task that touches a documented synchronization point.
- If no such list exists and the project clearly has cross-repo dependencies (multiple local clones owned by the user, generated clients, shared schema files), the agent SHOULD propose creating one.

### 14.3 Scope

This section covers impact on repositories the user controls or collaborates on. It does not require notification for general dependency updates (e.g., bumping a public package version), which are governed by the project's own update policy.

## 15. Issue Tracking — In-Repository Folders (Optional Convention)

When a project chooses to track bugs and feature requests as folders in the repository (rather than relying solely on external trackers like Jira, Linear, or GitHub Issues), the following conventions apply. This is a project-level decision documented in `codebase_rules.md`. The rulebook neither requires nor forbids the practice, but standardizes it where adopted.

**Rationale:** in-repo issue folders make the issue's full history (original report, root-cause analysis, evidence, fix artefacts) part of the codebase. They survive tracker migrations, work offline, are searchable with code-grep tools, and link naturally to commits via Conventional Commits scope.

### 15.1 Folder Layout

- **Bugs:** `BUGS/<bug-id>_<slug>/`
- **Features:** `FEATURES/<feat-id>_<slug>/` (case and exact directory name are project choice — `FEATURES/`, `Features/`, `features/`)
- The top-level folder names, the ID format, and the slug rules are defined in `codebase_rules.md`. The rulebook only requires that each issue have its own folder.

### 15.2 Required Internal Structure

Each issue folder MUST contain:

- **A report file** describing the original problem (for bugs) or request (for features). Filename is project choice (`report.md`, `bug_report.md`, `request.md`, …) but documented in `codebase_rules.md`.
- **A verification subfolder** (`verification/`, `tests/`, or equivalent) holding evidence that the issue was reproduced (for bugs) or accepted (for features), and later resolved. An empty `.gitkeep` is acceptable until populated.

Each issue folder MAY contain (depending on project type):

- **An analysis file** documenting root-cause investigation (for bugs) or design (for features) — often the most-read artefact during incident review.
- **An artifacts subfolder** holding implementation outputs (patches, migrations, scripts, generated files) tied specifically to this issue.
- **Communication artefacts** (email drafts, stakeholder summaries) when the issue requires external coordination.

The exact set of required and optional files is enumerated in `codebase_rules.md`.

### 15.3 Sensitive Data in Reports (HARD-LOCK)

Report files, analysis files, and any artefact under an issue folder are tracked artefacts. They MUST follow Section 2.4 anonymization rules. Reproduce by reference (`record #N in table T`, `[ACCOUNT]`, masked digits), never by value. The convenience of having full context next to the fix does NOT override the sensitive-data hard-lock.

### 15.4 Lifecycle

The issue folder is created at intake and persists for the life of the repository. Closure is recorded **inside** the folder (via a status field in the report file or a final summary section), not by deleting or moving the folder. This preserves the audit trail.

Lifecycle state names (e.g., `open`, `investigating`, `in_progress`, `resolved`, `wont_fix`, `abandoned`) are project-defined in `codebase_rules.md`. The rulebook only requires that the chosen names be documented and used consistently.

### 15.5 Linking to Commits and Plans

- **Conventional Commits scope:** when committing changes that resolve an issue, the commit scope SHOULD reference the issue ID (e.g., `fix(BUG-042): …`, `feat(FEAT-007): …`). Multiple IDs are comma-separated when one commit resolves several issues.
- **AI_tasks plans:** when an issue requires a formal plan (per Section 4), the plan in `AI_tasks/planned/` references the issue folder path, and the issue folder's report file references the plan path. The two cross-reference; they never duplicate content.

### 15.6 Cross-Repository Issues

When an issue spans multiple repositories (e.g., a backend bug whose fix also requires regenerating a client in a sibling repo):

- The issue folder lives in **the repository where the technical fix is implemented** — typically the repository owning the root cause.
- Sibling repositories reference the canonical folder by path (relative or full URL) in their own commit messages and any local follow-up tasks.
- Do NOT duplicate the issue folder across repositories. Duplicates drift; references stay correct.
- Cross-repo impact for the fix itself is governed by Section 14.

### 15.7 Relationship to External Trackers

In-repo issue folders are **complementary** to external trackers, not a replacement. A project may:

- Use folders only (no external tracker)
- Use external tracker only (no folders) — in which case this section does not apply
- Use both, with the folder as the technical source of truth (reproductions, analyses, fix artefacts) and the tracker as the management and stakeholder-visibility layer (priority, sprint, assignee)

When both are used, `codebase_rules.md` documents how they map (e.g., `BUG-NNN` folder ↔ `PROJ-NNN` ticket) and which side is authoritative for each field.

---

## Changelog

### v2.2.1 (2026-05-08)

**Patch — installer fixes.** No rulebook content changes; ships updated install scripts.

- **`scripts/install.sh` REPO_ROOT detection (BUG FIX):** when precision-mod was used as a git submodule (Method B in AI_INSTALL.md) or a regular clone inside a parent project (Method A), the installer detected the submodule's own toplevel as the project root and bootstrapped `AI_Guidelines/`, `AI_tasks/`, `AGENTS.md`, etc. **inside** the precision-mod clone instead of in the parent project. Resolution order is now: `--root <path>` (explicit), superproject working tree (submodule case), parent-of-upstream's git toplevel (clone-inside-project case), `pwd` (last resort). A safety guard refuses to proceed if the resolved root is inside the upstream directory.
- **`scripts/install.sh` skills auto-copy:** `skills/session-save.md` and `skills/session-load.md` are now copied automatically into `.ai/commands/` during bootstrap. The previous "next steps" instructed users to copy them manually.
- **`scripts/install.sh` codebase_rules.md template:** the generated template now includes placeholder sections for the v2.2.0 per-project enumerations (production-flagged targets, sensitive data categories, privileged tooling wrappers, verification gates, cross-repo sync points, in-repo issue tracking).
- **`scripts/install.sh` `--root <path>` flag:** explicit project root override, useful when auto-detection cannot determine the parent project.
- **Same REPO_ROOT resolution applied to `setup-obsidian.sh`, `setup-openbao.sh`, `migrate-credentials.sh`** to prevent the same regression in adjacent flows.
- **Stale version banners** in `install.sh` (was `v2.1.0`) and the strings it generates (`planning_journal.md`, `AGENTS.md` template) updated to current version.

**Migration:** projects already on v2.2.0 do not need to re-run the installer. If a previous install bootstrapped artefacts inside `AI_Guidelines/precision-mod-upstream/`, move them to the project root manually and re-run from the parent project root with the v2.2.1 installer.

### v2.2.0 (2026-05-08)

**Non-breaking minor bump.** Six new universal hard-locks and conventions distilled from production use across multiple projects. All defer specifics to `codebase_rules.md`, preserving the codebase-agnostic philosophy of the rulebook.

**New sections:**
- **Section 2.3 — Production Boundary:** hard-lock requiring explicit, scoped authorization for any production-flagged action. Forbids inferring prod approval from non-specific affirmatives or multi-part prompts. Adds the contrapositive "no bundling" rule: the agent MUST NOT mix production and non-production actions in a single confirmation prompt.
- **Section 2.4 — Sensitive Data Handling:** hard-lock against sensitive data in tracked artefacts. Categories and placeholder schemes are defined per-project in `codebase_rules.md`. Cross-references Section 2.2 for credentials.
- **Section 14 — Cross-Repository Impact:** standard notification format (`⚠️ CROSS-REPO IMPACT: …`) when changes affect sibling repositories. Sync points documented per-project in `codebase_rules.md`. Explicitly a chat-time signal, not a commit-message marker.
- **Section 15 — Issue Tracking (In-Repository Folders):** optional convention for tracking bugs and features as folders in the repo, complementary to external trackers. Standardizes the folder/report/verification structure, the cross-reference to commits and plans, the anonymization rules (cross-references §2.4), and the policy for cross-repo issues. Numbering, severity, templates, and lifecycle state names remain project-defined.

**Extensions:**
- **Section 7 (Implementation Guidelines):** added mandatory tooling wrapper hard-lock — when a project provides a wrapper for a privileged operation, the agent must use it instead of the underlying CLI. Includes an explicit escape valve: when the wrapper does not support the operation, is broken, or is the artefact under modification, the agent must notify and request authorization before falling through.
- **Section 9 (To-do Rules):** added explicit verification gate hard-lock. Distinguishes state-changing tasks (concrete gate: test, lint, smoke, review, deploy health check) from investigative or read-only tasks (exit criterion: question answered, hypothesis confirmed/refuted). For plan-driven tasks the gate is the plan's `## Verification` section; for ad-hoc tasks defaults live in `codebase_rules.md`.

**Non-breaking:** existing projects gain new hard-locks but no rule that was previously valid becomes invalid. Each new rule has an escape valve in `codebase_rules.md` for project-specific definitions. Section 15 is explicitly opt-in.

**Migration:** projects upgrading from v2.1.0 should:
1. Pull the new rulebook
2. Add the per-project enumerations to `AI_Guidelines/codebase_rules.md`:
   - Production-flagged targets (Section 2.3)
   - Sensitive data categories and placeholders (Section 2.4)
   - Privileged tooling wrappers (Section 7)
   - Default verification gates and exit-criterion templates (Section 9)
   - Sibling repositories and cross-repo sync points (Section 14)
   - Issue folder conventions if adopting Section 15 (ID format, required files, lifecycle state names, severity)
3. The rulebook itself works without these additions; the additions tighten enforcement project by project.

### v2.1.0 (2026-05-08)
**Changes:**
- **Section 2.2 (Credential Management):** clarified that the secret-manager backend is optional and project-specific. The hard-lock is "no plaintext secrets in tracked files"; the choice of backend (OpenBao, HashiCorp Vault, 1Password / Bitwarden CLI, cloud Secrets Managers, system keychain, or `.gitignore`d `.env`) is up to the project and documented in `codebase_rules.md`. OpenBao remains the recommended reference implementation but is no longer presented as the default requirement.
- **Bootstrap and Quick Start:** OpenBao setup removed from the default install path. `scripts/setup-openbao.sh` is opt-in for projects that chose OpenBao.
- **Documentation:** README and `AI_INSTALL.md` reframed accordingly. `docs/credential-management.md` is now the OpenBao-specific guide and points to alternatives.
- **Section 2 (Golden Rules):** generalized the "external reads" exception so other home-directory bootstrap scripts (e.g., `~/.config/op/`) qualify alongside OpenBao's. Cross-reference fixed (Section 12 → Section 2.2).

**Non-breaking:** projects already on OpenBao continue to work unchanged.

### v2.0.0 (2026-04-13)
**Breaking changes:**
- **Git safety overhaul (Section 2.1):** replaced blanket "forbidden" list with 3-tier classification (ALLOWED / AUTHORIZED / FORBIDDEN). `git checkout`, `git stash`, `git add`, `git commit` are now ALLOWED without authorization. `git push`, `git merge`, `git rebase` require authorization. Only truly destructive commands (`reset --hard`, `push --force main`, `clean -fd`) remain FORBIDDEN.
- **Enforcement model:** git safety rules should be enforced by hooks (deterministic) in addition to agent instructions (probabilistic). Reference hook at `AI_Guidelines/hooks/git-safe.sh`.
- **Versioning scheme:** changed from patch-only (1.0.x) to semantic versioning.

**New sections:**
- **Section 2.2 — Credential Management:** OpenBao as default secret manager. Hard-lock rules: never store secrets in files, encrypted vault in repo, master key out-of-band. Includes setup script, migration from plaintext, and team sharing guide (`docs/credential-management.md`).
- **Section 12 — Session Persistence:** session logs with multi-host/multi-agent identification. Filename includes host, agent type, and topic for merge-safe collaboration. Mandatory frontmatter with identity fields.
- **Section 13 — Obsidian Vault Integration:** optional section for repos that double as Obsidian vaults. `.obsidian/` in `.gitignore`, docs next to code, MCP fallback.

**Changes:**
- **Section 2 (Golden Rules):** added workspace exception for external credential bootstrap scripts. Updated bootstrap to include `.ai/commands/` and `AGENTS.md` as cross-agent entry point.
- **Section 4 (Planning):** skills path now accepts both `AI_SKILLS/` and `.ai/commands/`. Origin agent list expanded to include `cursor`, `windsurf`, `local-llm`.
- **Section 7 (Implementation):** removed "prefer class-based Python" (belongs in codebase_rules.md, not generic rulebook). Removed language-specific guidance.
- **Section 10 (Context Window):** added `/session-save` trigger before `pre_compact_task_progress.md` creation.

### v1.0.0 (2026-01-14)
- Initial release.
