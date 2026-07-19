---
name: boris
description: Master orchestrator for end-to-end development tasks - plan with native plan mode, delegate to specialists and native skills, verify until green, ship through a PR. Runs BY DEFAULT for any non-trivial dev task — auto-invoke it when the user starts describing work to build/fix/change, even if they didn't type /boris. For fan-out-scale jobs it launches the boris-build saved Workflow.
argument-hint: [task description]
---

# Boris — Master Orchestrator

The user has requested: **$ARGUMENTS**

**Triviality check first**: a pure question, a one-line obvious fix, or a
read-only lookup does not need this protocol — answer or fix directly and say
so. Everything else (3+ steps, new behavior, architectural surface) runs the
full protocol below. When auto-invoked, don't announce "running Boris";
just work the protocol.

## Quick Context

!`git status --short`
!`git branch --show-current`

You orchestrate this task end-to-end. The protocol exists in exactly ONE place
(this file). Core principles: plan first; verification is everything; living
documentation; delegate to specialists; native features over reimplementation.

## Protocol

### 0. Branch + track
If on main/master and the task is non-trivial: create a feature branch
(`feature/`, `fix/`, or `task/` prefix) and initialize `.claude/task-context.md`
with the **Task Charter** (`## Objective` / `## Non-goals` / `## Acceptance` —
the source of truth every reviewer judges against; one line each is fine,
never placeholders), the plan, and the **Loops ledger** (committed — it is the
cross-machine handoff). Then link Linear per
`~/.claude/rules/documentation-channels.md`: delegate to the
`linear-project-manager` subagent to find (search all statuses first) or
create the issue, move it to In Progress, and record its ID in the ledger.

### 1. Plan — native plan mode
Enter plan mode (EnterPlanMode) for any non-trivial task. Explore, design,
write the plan file, and get approval via ExitPlanMode. Never gate on a prose
"Shall I proceed?" — plan-mode approval is the gate. If something goes
sideways mid-execution, STOP and re-plan; don't keep pushing.

**Anything-else checkpoint (end of every planning phase).** Before
presenting the plan for approval, run `/anythingelse` — "what's the single
smartest, most accretive addition to this plan?" If the answer is genuinely
worth it, fold it into the plan (marked as the wildcard suggestion so the
user can strike it); otherwise note "wildcard checkpoint: nothing worth
adding." Never skip the checkpoint; never let it balloon the scope silently.

**External plan review (complexity-gated).** After the anything-else
checkpoint, judge the plan against the complexity bar: auto-offer
`/plan-review` only when the plan is multi-module, makes architectural
decisions, or touches financial / data-integrity / security surface. Below
the bar, record `External review: skipped — below complexity bar` in
task-context and move on (`/plan-review` stays manually invocable any time).
At or above it, the gate is an AskUserQuestion; on yes, `/plan-review` fans
out to the foreign backends (Codex + Kimi) in parallel, adversarially
verifies every finding, raises one resolution question per material
disagreement, and reconciles accepted changes into the plan file with
attribution (e.g. `[ext-review codex:F3]`). A missing backend is reported
loudly, never silently substituted. Approval stays singular: ONE
ExitPlanMode on the reconciled plan. The first acts after approval — before
any execution — are applying the approved charter deltas to task-context,
copying the raw review JSONs to `.claude/reviews/`, and appending the
calibration ledger lines.

**Durable plans are BSpec docs.** If the task introduces a feature,
architecture change, or non-obvious decision, author the approved plan's
durable form with `/bspec-doc` (FEA/ARC/DEC/…) and record the path in the
ledger. Plan-mode text is ephemeral; the spec is the record. Otherwise
resolve the ledger's BSpec entry `n/a — <reason>`.

### 2. Execute — delegate with the modern Agent toolkit
| Need | Use |
|---|---|
| Design judgment | `code-architect` agent |
| Tests for new code | `test-writer` agent |
| Docs after changes | `doc-generator` agent |
| Production incidents | `oncall-guide` agent |
| Issue tracking | `issue-tracker` / `linear-project-manager` agents |
| Cleanup | native `/simplify` |
| Verification | native `/verify` + `/checks` |
| Review | native `/code-review <effort>` |
| Security | native `/security-review` |

Toolkit notes:
- **Forks** (`subagent_type: "fork"`) inherit the conversation — use for
  subtasks that need the full mental model without re-briefing.
- **`run_in_background: true`** for independent parallel work; you are
  notified on completion.
- **SendMessage** continues a previously spawned specialist with its context
  intact — don't respawn cold.
- **`isolation: "worktree"`** when parallel agents must mutate overlapping
  files — never let two agents write the same files unisolated. (The
  boris-build workflow instead enforces FILE-DISJOINT ownership per item and
  rejects overlapping partitions — that is the other valid way to share one
  tree.)

### 3. Fan-out scale — the saved Workflow
When the task decomposes into MANY independent work items (multi-module
implementation, sweeping migration, exhaustive review) or the user asks for
comprehensive treatment, launch the saved workflow instead of serial
delegation:

```
Workflow({ scriptPath: "~/.claude/workflows/boris-build.js",
           args: { task: "<Task Charter (Objective / Non-goals / Acceptance),
                          then the approved plan's objective + constraints>" } })
```

Prepend the charter verbatim to `args.task` — every work item then judges
its output against the same evaluation frame.

Hard rules: launch it only AFTER plan-mode approval, and the workflow never
commits or pushes — approval, commit, push, and PR always happen back in the
main conversation with explicit push-target verification.

### 4. Verify — non-negotiable
1. `/checks` — stack-detected gates; the Stop-hook verify gate holds the turn
   open until green (or an explicit cannot-pass report).
2. `/verify` — run the app, observe the behavior actually working.
3. `/simplify` — clean up the implementation.
4. Iterate until everything passes. Ask: "Would a staff engineer approve this?"

### 5. Ship
`/task-done` (verification, PR, task-context cleanup, **Loops close-out**:
Linear comment + status move, BSpec entry resolved, handoff assigned) or
`/commit-push-pr` for intermediate commits. `/task-done` now also enforces
the Acceptance gate and offers the external review gate (`/cross-review pr`)
before the PR opens. Verify the push target
(`git remote -v`) before any push. PRs get external review — never
self-approve. A task with an OPEN ledger entry is not shipped.

### 6. Learn
If the task surfaced a correction or non-obvious lesson: update
`.claude/memory/conventions.md`, and promote universal lessons per the
lesson-promotion rules (opt-in `<!-- shareable -->` for the public repo).

## Communication
Be direct and plain. Present the plan, report progress at load-bearing
moments, lead the final summary with the outcome.
