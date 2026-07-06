# Task Context — fix/install-retire-load-context

## Objective
Post-deploy fix: install.sh's Phase 3.5 retirement-removal list fell behind and
left stale files on upgraded machines. Found when deploying v3 to the user's
machine — `commands/load-context.md` (retired P3) and `agents/ci-integrator.md`
(retired 4b) lingered because neither has a same-named skill/agent successor
(so Phase 4.5's skill-based cleanup misses them) and neither was in the
explicit Phase 3.5 list.

## Changes
- install.sh Phase 3.5: added `commands/load-context.md` + `agents/ci-integrator.md`
  to the removal list, with a comment warning that retired-without-successor
  items MUST be listed here.
- test-install.sh: fixture now seeds both stale files; +2 assertions that they
  are removed on upgrade (would have caught this). 32/32.

## Verification
- install e2e 32/32, bash -n clean. The user's machine was cleaned manually
  (both stragglers removed); this fixes it for their other machines.
