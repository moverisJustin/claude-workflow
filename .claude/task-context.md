# Task Context — feature/phase2b-claude-md-slim

## Objective
Boris v3 upgrade, **Phase 2b: CLAUDE.md slimming** (fourth PR; #5-#7 merged).
The template was 309 lines — 5-10x over the documented ~200-line adherence
budget — loaded in full into every session on every machine.

## Design (verified against current docs)
- `~/.claude/rules/` is real (user-level rules, loaded before project rules).
- Rules without `paths:` load EAGERLY — reorganizing alone saves nothing;
  the savings come from trimming prose that skills now encode.
- HTML comments are stripped pre-injection: `<!-- shareable -->` costs 0 tokens.

## Changes
- **CLAUDE.md template: 309 → 70 lines** (boot, scope rules, quick reference,
  rules/memory pointers, core principles).
- **rules/** (installed to `~/.claude/rules/`): `git-safety.md` (10 lines),
  `workflow.md` (32), `learned-patterns.md` (the full Learned Patterns section,
  moved verbatim — now the lesson-capture target and sync point).
- **sync-lessons.sh** defaults retargeted: `~/.claude/rules/learned-patterns.md`
  ↔ repo `rules/learned-patterns.md`. Heading-based logic unchanged.
- **install.sh**: Phase 6.3 installs rules (learned-patterns seeded only when
  absent — never overwritten); Phase 7 is version-aware ("Quick Reference
  (Boris v3)" marker): pre-v3 machines get their CLAUDE.md Learned Patterns
  migrated into the local rules file via the ungated snapshot merge (private
  lessons preserved locally, never pushed), then the slim template installed.
- **uninstall.sh**: removes repo-shipped rules, KEEPS learned-patterns.md
  (the user's accumulated lessons).
- **scripts/test-install.sh** (new, in CI): fake-HOME end-to-end install —
  21 assertions covering v2→v3 migration, private-lesson preservation, the
  no-leak guarantee (repo tree byte-identical after install), retirements,
  idempotent double-run. Closes most of the long-open "fresh install e2e" item.
- update-claude-md skill rewritten to route lessons to the right destination;
  README/CHEATSHEET lesson-location references updated.

## Post-review hardening (12 findings, 0 refuted)
- CRITICAL fixed: migration used to swallow sync failures (`|| true`), print
  success, replace CLAUDE.md, and the marker blocked retries — silent loss of
  every lesson when the machine had a pre-existing heading-only rules file
  (sync crashed on empty sections under set -e). Now: empty sections are a
  no-op, migration success is verified before CLAUDE.md is touched, failure
  is loud and retryable.
- User-authored custom CLAUDE.md sections are carried over (not silently
  destroyed); dropped @import lines produce an explicit warning.
- Version detection moved to an HTML-comment stamp (`boris-version: 3`) —
  zero tokens, and user edits to prose headings can't trigger re-migration.
- Three load-bearing instructions restored to rules/workflow.md (specs
  upfront; plan mode for verification; diff behavior vs main).
- Stale CLAUDE.md-era messages fixed across sync-lessons/install/CHEATSHEET/
  session-start; README documents rules/.

## Verification
- test-install.sh 22/22, test-sync-lessons.sh 17/17, test-hooks.sh 36/36
  (all /bin/bash 3.2); installer syntax.

## Next (plan: ~/.claude/plans/calm-skipping-thunder.md)
Phase 3: memory hybrid (delete ROUTER/activeContext/sessionHistory machinery,
keep conventions/decisionLog/projectContext + task-context.md; agent memory
for specialists; slim session-start/end). Phase 4: /ci-loop → /loop, model
tiers, permissions overhaul, plugin packaging, scheduled maintenance.
