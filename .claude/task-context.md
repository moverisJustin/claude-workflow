# Task Context — feature/phase4a-model-tiers

## Objective
Boris v3 upgrade, **Phase 4a: model tiers + community-agent hygiene** (branched
straight off main; Phases 0-3 all merged). First slice of Phase 4.

Two concrete wins: (1) cap delegation cost by pinning each agent to an
appropriate model tier; (2) shrink the installed community surface and close the
tool-inheritance hole (90/105 community personas inherited full Write/Bash).

## Changes
- **Core 9 agents get explicit `model:` tiers**: opus (code-architect,
  oncall-guide — judgment), sonnet (test-writer, doc-generator, ci-integrator —
  implementers), haiku (git-guardian, issue-tracker, linear-project-manager,
  memory-bank — CRUD/deterministic).
- **Community deploy-time tiering** (`scripts/agent-tier.sh`, sourced by
  install.sh): dev personas (engineering/testing/design/specialized) → sonnet,
  full tools; advisory (sales/marketing/product/etc.) → haiku + read-only tools
  (only when they don't already declare tools). Injected into the ~/.claude
  COPY — vendored files stay upstream-faithful, so a resync never clobbers
  tiering (cleaner than the plan's "re-inject after sync" approach).
- **install.sh installs only MANIFEST-active community agents** (was: all 105).
  The MANIFEST was previously dead config for install — it only drove sync.
- **MANIFEST trimmed to 44 dev-focused active** agents; the other 61
  (sales/marketing/product/PM/support/game/paid-media + non-dev design/
  specialized) are commented opt-in, all 105 still vendored (offline enable:
  uncomment + re-run install.sh).
- sync-agency-agents.sh: documents that install applies tiers at deploy time.
- Docs (README/CHEATSHEET): counts (105→44 active), tiering + opt-in story.
- test-install.sh: +6 assertions (core tier present, only-active installed,
  opt-in not installed, deploy-time tier injected, vendored stays pristine).

## Verification
- install e2e 27/27, hooks 36/36, drift 5/5, sync-lessons 17/17 — /bin/bash 3.2.

## Next (Phase 4 remaining)
- 4b: /ci-loop → /loop + background tasks (fold ci-integrator agent in).
- 4c: permissions overhaul (settings.base.json — drop enumerated Linear MCP
  tools, tighten curl/ssh/sudo, fix deny bypasses).
- 4d: plugin packaging + migrate.sh (biggest/structural — may warrant its own
  decision on command namespacing).
- 4e: scheduled maintenance routine.
