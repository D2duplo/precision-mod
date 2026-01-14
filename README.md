# Precision-MOD

  Precision‑MOD (Precision‑checked Engineering Change Rules, Intent, Safety, I/O, Operations, and
  Non‑negotiable Modifications) is a rulebook and gate system that standardizes engineering practices, tool
  usage, planning, and verification across teams and agents.

  ## Purpose
  - Reduce regressions and operational risk through explicit hard‑locks.
  - Centralize rules as a single source of truth.
  - Provide consistent workflows for planning, changes, and verification.
  - Normalize documentation and traceability.

  ## What It Includes
  - **Canonical rulebook** with global rules and hard‑locks.
  - **Gates** for builds, databases, MCP checks, and file policies.
  - **Workflow** for planning, execution, and verification.
  - **Documentation discipline** for logs and indexes.

  ## How to Use the Rulebook (Start of a Codebase)
  At the very start of any task in a codebase:
  1. Read the canonical rulebook to internalize all active constraints.
  2. Read the codebase index and skills index (if applicable).
  3. If a compaction summary exists, read it first, then the rulebook, active plan, and index, and delete the
  summary before proceeding.

  This step is mandatory before making any changes.

  ## Key Concepts
  - **Hard‑locks**: Non‑negotiable rules (e.g., planning flow, git restrictions).
  - **Gates**: Automated checks (builds, DB, smoke MCP).
  - **Single Source of Truth**: One canonical rulebook for the project.
  - **Context discipline**: Compaction and context‑limit rules.

  ## Quick Start
  1. Read the canonical rulebook for the project.
  2. Plan changes when required.
  3. Implement only after plan approval.
  4. Run `precision-mod verify` where mandated.

  ## Typical Structure
  - `AI_Guidelines/PRECISION_MOD_RULEBOOK.md` — canonical rulebook.
  - `AI_Guidelines/codebase_rules.md` — project‑specific rules.
  - `.precision-mod/` — configuration and gates.
  - `precision-mod` — CLI entrypoint.

  ## Updating the Rulebook
  Only update the rulebook when explicitly requested by the user, and align with the official repository
  version.

  ## License
  Apache‑2.0
