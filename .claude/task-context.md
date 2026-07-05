# Task Context — feature/phase4b-ci-loop

## Objective
Boris v3 upgrade, **Phase 4b: non-blocking CI loop** (branched off main;
Phases 0-3 + 4a merged).

The `/ci-loop` skill ran `gh run watch --exit-status` in a FOREGROUND `!`bash
block, freezing the entire turn for the whole CI run (often 10+ min).

## Changes
- **skills/ci-loop/SKILL.md rewritten**: push, then watch CI as a BACKGROUND
  task (`run_in_background: true`) so the harness re-invokes on completion
  instead of blocking the session. Kept the fix taxonomy (TS/lint/format/test/
  build/infra) + 5-iteration circuit breaker; folded in ci-integrator's
  multi-CI detection note; added "never report a cancelled run as green".
  Mentions /loop as the tool for a persistent "keep-green" watcher.
- **Deleted agents/ci-integrator.md** — it duplicated the ci-loop protocol;
  the rewritten skill is self-contained. Core agents 9 → 8.
- Docs: README/CHEATSHEET/CLAUDE.md — core-agent count 9→8, ci-loop
  description (non-blocking background watch), removed ci-integrator rows.

## Verification
- install e2e / hooks / drift / sync-lessons suites; no ci-integrator refs
  remain outside this task-context.

## Next (Phase 4 remaining)
- 4c: permissions overhaul (settings.base.json) — adjacent to the settings.json
  format issue the user hit; drop 35 enumerated Linear MCP tools, tighten
  curl/ssh/sudo, fix trivially-bypassed deny rules.
- 4d: plugin packaging + migrate.sh — needs a decision on command namespacing.
- 4e: scheduled maintenance routine.
