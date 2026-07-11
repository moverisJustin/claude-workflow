# Task Context — install.sh Phase 7 v3→v3 template re-sync

**Branch**: claude/distracted-mendeleev-b47860
**Date**: 2026-07-11

## Task
Fix the installer gap where a `boris-version: 3`-stamped ~/.claude/CLAUDE.md is
never touched again, so template updates WITHIN v3 (e.g. the 2026-07-11 rules
list + quick-reference additions from PR #23) silently never reach installed
machines. Confirmed in production: post-#23 the installed CLAUDE.md had to be
synced by hand.

## Design (as shipped)
- Factored the replace+carry-over logic (known-heading awk filter → copy repo
  template → append custom sections → @import-loss warning) into shared
  `render_claude_md` / `report_carryover` functions used by BOTH the pre-v3
  migration and the new v3→v3 branch — identical preservation guarantees.
- v3→v3 branch: render a candidate (current template + carried-over custom
  sections) to a temp file, `cmp -s` against the installed file. Identical →
  no-op ("already at Boris v3 (template current)"); different → replace and
  report, Phase 1 backup as the recovery path.
- No minor version stamp: the content comparison is self-maintaining.
- Bonus fix the re-sync exposed: the carry-over awk treated `# Foo` lines
  INSIDE fenced code blocks (the template's Quick Reference grouping comments)
  as unknown headings and carried template code-block innards over as "custom"
  — now fence-aware (`/^```/ { fence = !fence }`).

## Verification
- scripts/test-install.sh: new v3→v3 fixture (stale template section incl.
  code-fence comment + custom section with @import) — 43/43 assertions pass.
- All 7 CI suites green locally (sync-lessons, hooks, install, drift-check
  smoke+regression, maintenance, plugin, bspec-validate + settings JSON).

## Loops
- **Linear**: MOV-2525 — In Review (PR #24 open). Move to Done only after the
  merge is verified (`gh pr view 24 --json state,mergedAt`).
- **BSpec**: n/a — installer bug fix; design rationale lives in the PR
  description, no durable architecture/decision content.
- **Handoff**: none
