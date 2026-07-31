# Task Context

## Branch
**Name**: claude/clarification-prompt-planning-0e8d47
**Created**: 2026-07-31
**Author**: Justin @ Moveris
**Base**: main @ 090a215
**Issue**: N/A

## Objective
Turn "Ask me more questions. Fill in all gaps. Don't make any dangerous
assumptions." into an enforced part of the workflow rather than a platitude:
a mandatory `/clarify` checkpoint in planning, a stop-and-ask rule during
execution, and a durable `## Assumptions` charter register that foreign
reviewers audit.

## Non-goals
- No hooks or harness enforcement — this is rules, skills, and docs only.
- `scripts/drift-check.sh` is deliberately NOT given a new required heading;
  that would retroactively WARN every existing task-context in every project.
- No change to the `/anythingelse` or `/plan-review` gates beyond ordering.

## Acceptance
- [x] `/clarify` skill exists with the six-axis taxonomy and the
      dangerous-assumption definition
- [x] `rules/workflow.md` carries a `## Clarify First` section covering both
      planning and execution; `documentation-channels.md` defines the
      Assumptions syntax
- [x] Charter plumbing: task-branch template, boris steps 0/1/2, task-done
      gate 2.6b + PR body, memory-context extraction, maintenance-check guard
- [x] Foreign reviewers get the register labelled UNVERIFIED and treat a
      false assumption as a spec-drift finding
- [x] All gates green: test-memory-context (65), test-drift-check (18),
      test-sync-lessons (17), test-install (44), maintenance-check clean,
      drift score 99 (no regression)
- [x] Deployed artifact verified by grepping `~/.claude`, not the installer's
      exit message

## Assumptions
- [x] confirmed: `install.sh` picks up `skills/clarify` with no manifest edit
      — verified, it globs `skills/*/` at install.sh:181, and `/clarify`
      appeared in the live skill list after install
- [x] confirmed: adding `Assumptions` to the memory-context charter
      alternation does not change packs for charter-less task-contexts —
      the "byte-identical legacy" assertion still passes
- [~] accepted: the execution-phase rule is "always stop and ask", which is
      stricter than the harness default (assume-and-log for non-dangerous
      gaps) — Justin chose this explicitly; it is one paragraph in
      `rules/workflow.md` to dial back if it proves too interrupting

## Plan
Approved plan: `~/.claude/plans/polished-soaring-ripple.md`

## Loops
- **Linear**: OPEN — awaiting confirmation to create the issue
- **BSpec**: n/a — workflow-process change, no durable architecture or
  product decision beyond what the rules files themselves record
- **Handoff**: none

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-31 | Execution gaps block rather than assume-and-log | Justin's explicit choice over the recommended non-blocking default |
| 2026-07-31 | `## Assumptions` is not a drift-check required heading | Would retroactively WARN every pre-existing task-context; the charter lint's own posture is "backfilled, not punished" |
| 2026-07-31 | `/clarify` runs before `/anythingelse` | The wildcard's best answer depends on the clarifications |

## Progress
### Done
- All plan items implemented, all gates green, artifact deploy-verified.

### In Progress
- PR not yet opened.

### Blocked
- Nothing blocked.

## Notes
The wildcard (`/anythingelse`) contribution was making the foreign models
attack the register: `memory-context.sh` labels `## Assumptions` UNVERIFIED
in every review pack, and `spec-drift.md` gained a third drift direction
("False assumption") alongside Drift and Scope creep. That is what makes the
"no dangerous assumptions" rule externally checked rather than self-policed.
