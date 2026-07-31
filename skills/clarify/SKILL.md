---
name: clarify
description: Ask the user the questions that close the gaps before building — a batched, six-axis sweep for unstated requirements, plus the dangerous-assumption rule. Auto-runs at the start of every planning phase (before /anythingelse) and on any gap discovered during execution; also invocable any time.
---

# Clarify — fill the gaps before you build

Ask more questions. Fill in all gaps. Make no dangerous assumptions.

This is a **question-generating** checkpoint aimed at the user, not a
brainstorm aimed at yourself (that is `/anythingelse`, which runs after this
one — what is smartest to add depends on the answers you get here).

## When it runs

- **Planning** — mandatory, at least one round, before the plan is presented.
- **Execution** — on any gap discovered after approval. Stop and ask.
- **Manually** — any time, on any task.

Trivial work is exempt: a pure question, a one-line obvious fix, a read-only
lookup. Say so and skip.

## The sweep — six axes

Walk all six. Most yield nothing on a given task; that is fine, the point is
that you looked rather than noticed.

1. **Scope boundary** — what is deliberately *not* in this task? What nearby
   thing am I likely to touch that you would rather I left alone?
2. **Success criteria** — how will you judge this done? What must the PR
   demonstrate? What does "working" look like to you specifically?
3. **Blast radius** — what else depends on this? What must not break? Who
   notices if it does?
4. **Data & state** — migrations, backfills, existing records, defaults for
   rows that predate the change, the rollback path.
5. **Interfaces & consumers** — who calls this, and what contract are they
   relying on that isn't written down?
6. **Constraints you have and I don't** — deadlines, prior attempts, approaches
   already ruled out, org or political facts, anything that lives in your head
   and nowhere in the repo.

## Seventh axis: is a teammate already in this code?

Only when the project has a forge repo — silent otherwise, so this costs
nothing for solo work:

```bash
bash ~/.claude/scripts/forge-bridge.sh collision "<branch>" "<objective>"
```

Each `COLLISION` line names a teammate, whether it matched their **plans**
(what they're about to do) or **wip** (what they're doing now), their entry
title, and the overlapping terms. A real overlap becomes one of the batched
questions:

> Eric's plan (2h ago) refactors the payments API you're about to change.
> Coordinate with him, wait for his branch to land, or proceed and absorb the
> conflict?

This is the cheapest possible moment to catch a collision — before a line is
written, rather than at merge. It is also the one thing this checkpoint can do
that reading a shared log passively cannot.

No output means no overlap. **Do not manufacture a question from a weak match**
— the matcher requires three shared non-generic terms precisely because a
noisy false positive trains you to ignore the real ones.

## How to ask

- **Batch.** One `AskUserQuestion` call, up to 4 questions, highest-leverage
  first. Never trickle questions one per turn.
- **Make options concrete.** Each option says what will actually happen if
  chosen, including the trade-off. Lead with a recommendation when you have
  one and mark it `(Recommended)`.
- **Do the free work first.** Anything answerable by reading the code, the
  Memory Bank, `conventions.md`, or git history is not a question — go look.
  Only ask what genuinely lives in the user's head.
- **Never ask for approval here.** "Is the plan okay?" is `ExitPlanMode`'s job.

## Declare the result out loud

Silence is not a pass. Every checkpoint ends in one of two statements:

- the batched questions, or
- **"Clarification checkpoint: no material gaps."**

## Dangerous assumptions

An assumption is **dangerous** when acting on it could be irreversible or
reaches beyond the working tree:

- **Destructive / irreversible** — deletes, overwrites, force-push, dropped
  schema, discarded history
- **Outward-facing** — push, deploy, publish, send, post, any external API
  write
- **Security** — credentials, auth, permissions, secrets, access scope
- **Data integrity** — migrations, backfills, financial or participant data
- **Cost-incurring** — paid APIs, compute spend
- **Scope-redefining** — changes what the task fundamentally *is*

**A dangerous assumption is never taken silently, in any mode, at any stage.**
Stop and ask, every time. No amount of "it's probably fine" or inferred
prior authorization substitutes for the answer.

## During execution: stop and ask

Any gap discovered after plan approval **halts the work until it is answered**.
Do not build on a guess and flag it later.

Two mechanics, which are not softenings of that rule:

- **Batch what surfaces together.** If three gaps appear at once, they go in
  one `AskUserQuestion` call, not three consecutive halts.
- **Subagents cannot ask.** A delegated agent has no `AskUserQuestion`. Brief
  every implementer to **return the question instead of guessing** — a work
  item that hits a gap stops and reports it — and surface it from the main
  thread. An agent that guesses to avoid stalling has broken this rule.

## Record what you did not ask

Every assumption you take without asking goes in the `## Assumptions` section
of the branch's `.claude/task-context.md` charter — the register travels into
the PR body and into every foreign-review pack, so it gets audited rather than
forgotten.

```markdown
## Assumptions
- [ ] assumed: <what I took as true, and what breaks if it isn't>
- [x] confirmed: <validated — how>
- [~] accepted: <what> — <why living with it is safe>
```

`- [ ] assumed:` is an open loop. `/task-done` will not report complete while
one is still open.
