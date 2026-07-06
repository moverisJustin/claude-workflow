# Task Context — feature/phase4e-maintenance

## Objective
Boris v3 upgrade, **Phase 4e: local scheduled maintenance** (user chose the
local, no-cloud option). Off settled main (Phases 0-3 + 4a/4b/4c merged).

Attacks the repo's own documented failure mode — docs drifting from reality
("15 agents, 23 commands") — on a clock instead of on human memory.

## Changes
- **scripts/maintenance-check.sh** (new): self-audit that recomputes the real
  counts of core agents / skills / hook scripts / community (active+vendored)
  and compares them to the numbers README + CHEATSHEET claim. Doc-count
  mismatches are hard findings (exit 1); Memory Bank drift is ADVISORY only
  (the repo's memory is gitignored scratch, and drift-check already runs at
  session boundaries + post-commit). `--install-cron`/`--uninstall-cron` use
  the safe temp-file pattern (never `grep -v | crontab -` under set -e).
- **CI**: added test-maintenance.sh (7 tests) + a "Docs match reality" step
  that runs maintenance-check on every PR — so a count can never silently
  drift again (self-enforcing).
- **scripts/test-maintenance.sh** (new): fixture-based regression tests
  (matching counts -> clean; stale counts -> drift, named).
- README: new "Self-Audit" subsection (what it checks, how to schedule).

## Verification
- self-audit clean on the repo; test-maintenance 7/7; install e2e 30/30,
  hooks 36/36, drift 5/5, sync-lessons 17/17 - /bin/bash 3.2.

## Remaining
- 4d: plugin packaging (bare-name-preserving skills-dir form, per the user's
  pick). Last piece. Needs a research pass on plugin.json/marketplace.json
  format before building; install.sh survives (plugins can't ship permissions).
