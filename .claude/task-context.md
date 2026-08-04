# Task Context

## Branch
**Name**: claude/missing-review-steps-d78b03
**Created**: 2026-08-04
**Author**: Justin @ Moveris
**Base**: main
**Issue**: N/A

## Objective
The planning checkpoints (`/anythingelse`, `/plan-review`, `/cross-review`) were
documented as mandatory but measurably were not running — 11 of 77 plan
approvals for `/anythingelse`, 3 for `/plan-review`, 0 for `/cross-review`.
Make them enforced rather than merely documented, let an autonomous session
reach `/task-done`, and stop the OpenRouter/Kimi review dying at 300 s.

## Non-goals
- The compliance meter (W5) — deliberately deferred until the gate is proven.
- Unlocking `ci-loop` or `commit-push-pr`; both verified unsafe as written.
- Covering `gh api .../pulls` or the GitHub web UI as PR-creation paths.

## Acceptance
- [x] A hook denies `ExitPlanMode` when the checkpoints have not run this episode
- [x] Evidence comes from the transcript, not a forgeable self-report
- [x] `task-done` + `task-branch` are model-invocable, with mechanical (not prose) containment
- [x] Kimi reviews survive a slow generation and abort fast on a real stall
- [x] All gates green and the change verified in the INSTALLED config, not just the repo

## Assumptions
- [x] confirmed: `deny` is honored on `ExitPlanMode` — proven by live spike, not docs
- [x] confirmed: `transcript_path` exists in the PreToolUse payload — dumped a real one
- [x] confirmed: `agent_id` does NOT exist — the planned subagent guard was vacuous; none needed
- [~] accepted: raising the wall clock 300→600 s exceeds the approved plan's locked 300 s.
  The plan locked it *because* keepalives could defeat idle detection; that is now
  fixed and tested, so the stated reason no longer holds. Flagged for veto.

## Checkpoints
- [x] clarify: swept six axes; asked 4 — gate force, blast radius, unlock scope, Kimi
  approach. Answers: ask / task-branches-only / spine / stream+idle. Two were later
  overturned by review (ask is inert on ExitPlanMode; 2 of 4 unlock targets unsafe).
- [x] wildcard: proposed a committed compliance meter (`protocol-compliance.sh`) so the
  next regression is visible. Folded in as W5, then **dropped** after review argued it
  is a closed loop — the agent measured writes the meter and generates its own events.
- [x] plan-review: codex + kimi, both `revise`. 20 findings raised, 19 folded in, 1
  refuted (kimi F10: `/cross-review pr` does not need an existing PR — it reads
  `git diff <base>...HEAD`). Independent agreement on 5 findings.
- [ ] cross-review: pending — PR-stage review not yet run

## Plan
- [x] Spike: prove `deny` blocks ExitPlanMode + dump payload
- [x] W4 foreign-review.sh streaming + content-aware idle abort
- [x] W1 hook-plan-gate.sh
- [x] W3 `## Checkpoints` section + write path + readers
- [x] W2 unlock + PUBLISH containment
- [x] Deploy + verify installed artifact
- [ ] Live enforcement test against installed config
- [ ] PR

## Loops
- **Linear**: OPEN
- **BSpec**: OPEN
- **Handoff**: none
- **Forge**: n/a — no forge repo for claude-workflow

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-08-04 | Gate with `deny`, not `ask` | `ask` is discarded on ExitPlanMode (requiresUserInteraction); a gate built on it is silent theatre |
| 2026-08-04 | Evidence from transcript, not task-context | Plan mode cannot write task-context (deny would deadlock) and the block is one Edit from forged |
| 2026-08-04 | Scope to plan episode, not `prompt_id` | A planning phase spans several prompts; prompt-scoping false-denies nearly always |
| 2026-08-04 | Drop `ci-loop` from the unlock set | `git push` is step 1 with no branch guard, no allowed-tools, no remote check |
| 2026-08-04 | Hold `commit-push-pr` | Guards only literal main/master; pushes to `develop` in gitflow with no human gate |
| 2026-08-04 | Idle measured on parsed content, not wire bytes | OpenRouter keepalive comment frames are wire bytes and would defeat the check |
| 2026-08-04 | Defer the compliance meter | Closed measurement loop; prove the gate first |

## Progress
### Done
- All five workstreams implemented, tested, and deployed to `~/.claude`
- 305 assertions green across 5 suites; maintenance-check clean

### In Progress
- Live enforcement test against the installed configuration

### Blocked
- [nothing blocked]

## Notes
The gate's own tests assert its OUTPUT contract only. `test-hooks.sh` cannot tell
"emitted correct JSON" from "the CLI acted on it" — that distinction was settled by
a live spike and must be re-checked live after any install.
