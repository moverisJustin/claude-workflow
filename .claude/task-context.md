# Task Context

## Branch
**Name**: claude/multi-model-orchestration-6c566a
**Created**: 2026-07-11
**Author**: Justin @ Moveris
**Base**: main @ 95c83f2
**Issue**: see Loops

## Objective
Close the workflow's unintentionally-open loops: one documentation contract
(Linear tracking + BSpec docs + explicit handoffs) applied by default at every
entry and exit point (/task-branch, /boris, /fix-issue, /session-start,
/session-end, /task-done), enforced via a Loops ledger in task-context.

## Plan
- [x] Research DSPy, "Orce Dev" (unresolved name — likely Orca/Orcha/orc), Shopify/Qwen pattern
- [x] Audit existing loop-closing mechanics (only hard gate: /checks Stop hook)
- [x] Write rules/documentation-channels.md (the contract)
- [x] Wire Linear close-out into task-done, session-end, boris, task-branch, fix-issue
- [x] Wire BSpec defaults into session-start, boris, task-branch
- [x] Update CLAUDE.md, README, rules/workflow.md
- [x] BSpec DEC record (specs/DEC-documentation-channels-v1.0.0.md)
- [ ] Commit, push, PR (removes this file for merge — also cleans the stale
      memory-migrate task-context accidentally left on main)
- [ ] Follow-ups (separate tasks): /cross-review Codex adversarial-review skill; DSPy/GEPA pilot on Moveris QA gate; eval-gated skill edits

## Loops
- **Linear**: MOV-2522 (In Progress)
- **BSpec**: specs/DEC-documentation-channels-v1.0.0.md
- **Handoff**: none

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-11 | Contract in one rule file; skills reference it | Protocol lives in exactly one place |
| 2026-07-11 | Skill-level enforcement first; Stop-hook loop-gate deferred | Cheap + reversible; escalate only if ledger still leaks |
| 2026-07-11 | decisionLog.md stays an index; substantial decisions get BSpec DEC docs | Avoid two competing ADR homes |

## Progress
### Done
- Contract + 6 skills + docs + BSpec DEC record (validated)

### In Progress
- Linear issue link, commit/PR

### Blocked
- "Orce Dev" identity unconfirmed (user to clarify: Orca / Orcha / orc?)

## Notes
Research findings (DSPy transfer ideas, Shopify/Qwen pattern, Orce candidates)
are in the session transcript of 2026-07-11; recommendations #3-#5 from that
session are intentionally out of scope for this branch.
