# Precision-MOD

**`v2.0.0`** | Apache-2.0 | [Rulebook](PRECISION_MOD_RULEBOOK.md) | [Installation Guide](AI_INSTALL.md)

---

A rulebook and gate system for AI coding agents. Precision-MOD enforces planning discipline, git safety, credential management, session persistence, and documentation standards across any codebase and any agent runtime.

Supported agents: Claude Code, Cursor, Windsurf, Gemini CLI, Codex CLI, local LLMs.

Proven in production across real codebases with 100+ completed tasks.

## What it does

Precision-MOD provides a single source of truth for engineering constraints that AI agents must follow. It is **codebase-agnostic** -- project-specific rules live in a separate `codebase_rules.md` file that you maintain.

| Capability | Description |
|---|---|
| **Hard-locks** | Non-negotiable constraints enforced by hooks and agent instructions |
| **Planning discipline** | Formal task lifecycle: planned, queued, in_progress, completed |
| **Git safety** | 3-tier command classification (ALLOWED / AUTHORIZED / FORBIDDEN) with hook enforcement |
| **Credential management** | OpenBao-based secret management (AES-256-GCM, file-based, offline). Includes setup, migration from plaintext, and team sharing. Alternative backends supported. |
| **Session persistence** | Multi-host, multi-agent session logs with identity tracking (host, user, agent_type, model) |
| **Documentation standards** | Conventional Commits, planning journal, filetree index |

## What changed in v2.0.0

| Area | v1.x | v2.0.0 |
|---|---|---|
| Git safety | Blanket forbidden list (instructions only) | 3-tier classification with deterministic hook enforcement |
| Credentials | No formal policy | OpenBao integrated (setup, migration from plaintext, team sharing). Encrypted vault in repo, master key out-of-band |
| Session logs | Single-agent, no identity | Multi-host/multi-agent with identity fields; merge-safe for teams |
| Obsidian integration | None | Optional -- repo can double as an Obsidian vault (`.obsidian/` in `.gitignore`) |
| Cross-agent skills | None | `.ai/commands/` as canonical skills directory, indexed in `AI_SKILLS/INDEX.md` |
| Bootstrap | Manual setup | Agent proposes structure on first run |

## Quick start

1. Clone or add as a submodule inside your project's `AI_Guidelines/` directory:
   ```bash
   cd your-project
   git submodule add https://github.com/D2duplo/precision-mod.git AI_Guidelines/precision-mod-upstream
   ```
2. Run the bootstrap (or let the agent propose it on first run when it detects missing structure).
3. Configure `AI_Guidelines/codebase_rules.md` with your project-specific rules.
4. Point your agent entry files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) at the rulebook:
   ```
   MANDATORY: At the start of every task, read AI_Guidelines/PRECISION_MOD_RULEBOOK.md,
   filetree.md, and AI_SKILLS/INDEX.md.
   ```

## Project structure (after bootstrap)

```
your-project/
├── AI_Guidelines/
│   ├── precision-mod-upstream/      <- this repo (submodule or clone)
│   │   ├── PRECISION_MOD_RULEBOOK.md
│   │   ├── AI_INSTALL.md
│   │   ├── docs/credential-management.md
│   │   └── scripts/
│   │       ├── install.sh
│   │       ├── setup-openbao.sh     <- credential manager setup
│   │       ├── migrate-credentials.sh <- migrate plaintext to OpenBao
│   │       ├── setup-obsidian.sh
│   │       ├── vault-autocommit.sh
│   │       └── git-safe.sh
│   ├── codebase_rules.md            <- your project-specific rules
│   └── hooks/
│       └── git-safe.sh              <- optional enforcement hook
├── .openbao/                        <- encrypted credentials (committed)
│   ├── config.hcl
│   └── data/                        <- AES-256-GCM encrypted
├── AI_SKILLS/
│   └── INDEX.md
├── AI_tasks/
│   ├── planned/
│   ├── queued/
│   ├── in_progress/
│   └── _completed/
├── .ai/commands/                    <- cross-agent skills
├── 99_Inbox/session-logs/           <- session persistence
├── AGENTS.md                        <- cross-agent entry point
├── filetree.md
└── planning_journal.md
```

## Core principles

**Hard-locks are non-negotiable.** They are enforced both by agent instructions and by deterministic hooks (e.g., pre-commit). An agent cannot override a hard-lock, even if instructed to by the user in-context.

**Plan before you build.** Every non-trivial change follows the task lifecycle: `planned/` (draft) -> `queued/` (approved) -> `in_progress/` (active) -> `_completed/` (done). Micro-changes (single file, 30 lines or fewer, no public contract changes) are exempt.

**Git commands are classified, not blanket-banned.**

| Tier | Examples | Policy |
|---|---|---|
| ALLOWED | `status`, `log`, `diff`, `add`, `commit`, `checkout`, `stash`, `branch`, `blame`, `show`, `describe`, `ls-files` | Always permitted |
| AUTHORIZED | `push`, `pull`, `merge`, `rebase`, `cherry-pick`, `revert`, `tag`, `checkout -- <file>`, `branch -d/-D` | Require explicit user authorization per invocation |
| FORBIDDEN | `push --force` (without `--force-with-lease`), `reset --hard`, `clean -fdx`, `filter-branch`, `checkout -- .`, `restore .` | Blocked unconditionally; enforced by hooks |

**Secrets never touch files.** Credentials are managed by OpenBao — an open-source, offline-capable secret manager with AES-256-GCM encryption. The encrypted vault (`.openbao/data/`) is committed to the repo; the master key stays out-of-band. Agents retrieve credentials at runtime via `bao kv get`. Existing plaintext credentials can be migrated with `scripts/migrate-credentials.sh`.

**Sessions survive context resets.** Each agent writes a session log with identity fields so that any agent (or the same agent after a context window reset) can resume work.

## Links

- **Full rulebook:** [PRECISION_MOD_RULEBOOK.md](PRECISION_MOD_RULEBOOK.md)
- **Installation guide:** [AI_INSTALL.md](AI_INSTALL.md)
- **Upstream repository:** [github.com/D2duplo/precision-mod](https://github.com/D2duplo/precision-mod)
- **License:** [Apache 2.0](LICENSE)
