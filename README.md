# Precision-MOD

**`v2.2.0`** | Apache-2.0 | [Rulebook](PRECISION_MOD_RULEBOOK.md) | [Installation Guide](AI_INSTALL.md)

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
| **Credential management** | Hard-lock: no plaintext secrets in tracked files. Backend (OpenBao, HashiCorp Vault, 1Password / Bitwarden CLI, AWS / GCP / Azure Secrets Manager, system keychain) is optional and project-specific. OpenBao reference scripts included for projects that want it. |
| **Session persistence** | Multi-host, multi-agent session logs with identity tracking (host, user, agent_type, model) |
| **Documentation standards** | Conventional Commits, planning journal, filetree index |

## What changed in v2.2.0

| Area | v2.1.0 | v2.2.0 |
|---|---|---|
| Production safety | Implicit (covered by general "deletes require permission" only) | **§2.3 Production Boundary** — explicit, scoped authorization per prod action and target; no inferring approval from a "yes" to a multi-part prompt; agent must not bundle prod with non-prod in one confirmation |
| Sensitive data | Only credentials covered (§2.2) | **§2.4 Sensitive Data Handling** — hard-lock against PII / financial IDs / internal data in tracked artefacts; categories and placeholders in `codebase_rules.md` |
| Privileged tooling | Not addressed | **§7 wrapper hard-lock** — where a project ships a wrapper for a privileged op, the agent must use it; explicit escape valve when the wrapper is missing a feature, broken, or the artefact under modification |
| Task completion | Negative rule only ("don't complete with failing tests") | **§9 verification gate** — every task declares its gate (concrete check for state-changing tasks, exit criterion for investigative tasks) before being marked complete |
| Cross-repo impact | Not addressed | **§14 Cross-Repository Impact** — standard `⚠️ CROSS-REPO IMPACT: …` chat-time notification when a change affects a sibling repo |
| Issue tracking | Not addressed | **§15 In-Repo Issue Tracking** (opt-in) — `BUGS/` and `FEATURES/` folder convention with report + verification + cross-link to commits and plans; complements external trackers |

Non-breaking: existing projects upgrade by pulling the rulebook and adding per-project enumerations to `codebase_rules.md`. §15 is explicitly opt-in.

## What changed in v2.1.0

| Area | v2.0.0 | v2.1.0 |
|---|---|---|
| Credential backend | OpenBao framed as default; "alternative backends supported" was a footnote | Backend choice is **optional and project-specific**. Hard-lock is "no plaintext secrets in tracked files"; OpenBao is one of several supported options (HashiCorp Vault, 1Password / Bitwarden CLI, cloud Secrets Managers, system keychain) and stays the recommended reference implementation |
| Bootstrap | OpenBao implied in canonical project structure (`/.openbao/`) | OpenBao is opt-in; default install path no longer touches it |
| `docs/credential-management.md` | Read as the credential-management guide | Read as the OpenBao-specific guide, with pointers to alternatives |

Non-breaking: existing OpenBao adopters need no changes.

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
│   │       ├── setup-openbao.sh     <- optional: only if using OpenBao
│   │       ├── migrate-credentials.sh <- optional: OpenBao migration helper
│   │       ├── setup-obsidian.sh
│   │       ├── vault-autocommit.sh
│   │       └── git-safe.sh
│   ├── codebase_rules.md            <- your project-specific rules
│   └── hooks/
│       └── git-safe.sh              <- optional enforcement hook
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

> **Optional add-on — OpenBao vault.** If the project chooses OpenBao as its secret backend, an additional `.openbao/` directory holds the encrypted vault (`config.hcl` + `data/`, AES-256-GCM, safe to commit). Run `scripts/setup-openbao.sh` to provision it. Other backends (HashiCorp Vault, 1Password, cloud Secrets Managers, system keychain) leave no extra directory in the repo.

## Core principles

**Hard-locks are non-negotiable.** They are enforced both by agent instructions and by deterministic hooks (e.g., pre-commit). An agent cannot override a hard-lock, even if instructed to by the user in-context.

**Plan before you build.** Every non-trivial change follows the task lifecycle: `planned/` (draft) -> `queued/` (approved) -> `in_progress/` (active) -> `_completed/` (done). Micro-changes (single file, 30 lines or fewer, no public contract changes) are exempt.

**Git commands are classified, not blanket-banned.**

| Tier | Examples | Policy |
|---|---|---|
| ALLOWED | `status`, `log`, `diff`, `add`, `commit`, `checkout`, `stash`, `branch`, `blame`, `show`, `describe`, `ls-files` | Always permitted |
| AUTHORIZED | `push`, `pull`, `merge`, `rebase`, `cherry-pick`, `revert`, `tag`, `checkout -- <file>`, `branch -d/-D` | Require explicit user authorization per invocation |
| FORBIDDEN | `push --force` (without `--force-with-lease`), `reset --hard`, `clean -fdx`, `filter-branch`, `checkout -- .`, `restore .` | Blocked unconditionally; enforced by hooks |

**No plaintext secrets in tracked files.** This is the hard-lock. The backend you use to keep that promise — OpenBao, HashiCorp Vault, 1Password / Bitwarden CLI, a cloud Secrets Manager, the system keychain, or a `.gitignore`d `.env` — is the project's choice and is documented in `AI_Guidelines/codebase_rules.md`. Precision-MOD ships an OpenBao reference (setup script, migration tool, full guide) for projects that want a turnkey self-hosted vault, but no backend is required out of the box.

**Sessions survive context resets.** Each agent writes a session log with identity fields so that any agent (or the same agent after a context window reset) can resume work.

## Links

- **Full rulebook:** [PRECISION_MOD_RULEBOOK.md](PRECISION_MOD_RULEBOOK.md)
- **Installation guide:** [AI_INSTALL.md](AI_INSTALL.md)
- **Upstream repository:** [github.com/D2duplo/precision-mod](https://github.com/D2duplo/precision-mod)
- **License:** [Apache 2.0](LICENSE)
