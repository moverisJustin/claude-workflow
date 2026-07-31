---
name: task-done
description: Complete a task branch - verify, create PR, and clean up task-context.md for merge.
disable-model-invocation: true
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git commit:*), Bash(git remote:*), Bash(git push:*), Bash(git rm:*), Bash(gh pr create:*)
---

# Complete Task Branch

## Current State
!`git branch --show-current`
!`git status --short`

Read `.claude/task-context.md` using the Read tool.

---

## Task Completion Protocol

### 0. Pre-flight Checks

- Confirm we are **NOT on main/master**. If we are, abort: "Cannot run /task-done on main. Switch to your task branch first."
- If `.claude/task-context.md` does not exist, warn but continue: "No task-context.md found. Proceeding without task context."
- Read the `## Loops` ledger (see `~/.claude/rules/documentation-channels.md`).
  If the task-context predates the ledger, **backfill it now** (Linear / BSpec
  / Handoff) — do not skip it.
- Read the **Task Charter** (`## Objective` / `## Non-goals` / `## Acceptance`
  / `## Assumptions` in task-context.md). If any charter section is missing or
  still placeholder text, **backfill it now** from what the branch actually did
  — same treatment as the ledger backfill, do not skip it. (`## Assumptions`
  absent from a pre-register task-context is a vacuous pass, not a defect:
  backfill it if the branch actually made assumptions, otherwise leave it.)

### 1. Update Task Context

If task-context.md exists, update it:
- Mark completed plan items as done
- Update Progress section
- Add a Completion Summary:

```markdown
## Completion Summary
**Completed**: [YYYY-MM-DD]
**Commits**: [count on this branch vs main]
**Summary**: [1-2 sentence description of what was accomplished]
```

### 2. Run Verification

Run `/checks` (stack-detected quality gates — tests, types, lint, format,
build). Do NOT mask failures with `2>/dev/null || true` chains: a gate that
fails must surface its output, and the verify gate stays armed until every
applicable gate passes.

If any gate fails, stop and fix root causes before proceeding. For changes
where behavior matters (not just static gates), also run `/verify` to
observe the app actually working.

### 2.5. Close the Loops Ledger

**Do not report "Task Complete" while any ledger entry is OPEN.** Resolve
each one now (or waive it with an explicit reason):

- **BSpec**: did this task introduce a feature, architecture change, or
  non-obvious decision? → author/update the spec with `/bspec-doc` and record
  the path. Otherwise record `n/a — <reason>`. Substantial decisions get a
  BSpec DEC doc; `.claude/memory/decisionLog.md` links to it (index only).
- **Handoff**: if the work passes to someone else, assign the Linear issue to
  them and leave a context comment (what's done, what's left, where the spec
  lives). Otherwise `none`.
- **Linear**: confirm the issue ID is recorded (search/create via the
  `linear-project-manager` subagent if it was never linked). The final status
  move + comment happens in step 6.5 once the PR URL exists.

### 2.6. Acceptance Gate

**Do not report "Task Complete" while any `## Acceptance` item is still
`- [ ]`.** Walk the charter's Acceptance list now: mark each criterion the
work verifiably meets `- [x]`; anything you cannot check gets resolved
(finish it) or explicitly waived as `- [~] waived: <reason>`. An unchecked,
unwaived item means the task is not done — deleting or silently skipping an
item is not an option.

### 2.6b. Assumption Gate

**Do not report "Task Complete" while any `## Assumptions` entry is still
`- [ ] assumed:`.** Walk the register: each entry the work verifiably settled
becomes `- [x] confirmed: <what — how it was validated>`; each one you are
knowingly living with becomes `- [~] accepted: <what> — <why it's safe>`.
An assumption that turned out **wrong** is not retired here — it is a defect:
fix the work, then record the correction.

Deleting an entry to clear the gate is not an option. A charter with no
`## Assumptions` section passes vacuously (older branches predate the
register).

### 2.7. External Review Gate

After `/checks` is green and before any PR commit, offer decorrelated
review. Ask via AskUserQuestion:

> External PR review before opening the PR?
> [All configured backends / Codex only / Skip]

- **All configured backends** → run `/cross-review pr`.
- **Codex only** → run `/cross-review pr --models codex`.
- **Skip** → record `External review: skipped — <reason>` in task-context
  and continue.

If the review returns CONFIRMED **critical or high** findings, ask which way
to resolve them:
- **Fix now** → apply the fixes, re-run `/checks`, and note that findings
  touched by the fixes need re-review (re-run the affected backend or verify
  the fix directly).
- **Ship with known issues** → carry them into the PR body's
  `## Known Issues (external review)` block in step 6 — never drop them
  silently.

A missing or unavailable backend is reported loudly and never silently
substituted — `/cross-review`'s own degradation rules apply.

### 3. Commit Any Remaining Changes

```bash
git add -A
git status --short
# If there are uncommitted changes, commit them with conventional message
```

### 4. Prepare for PR

Capture task context for the PR body:
- Read the Task Charter (Objective, Non-goals, Acceptance with final check
  states, Assumptions with final retirement states) from task-context.md
- Read Completion Summary
- If the external review gate (2.7) ran, capture its summary (backends,
  confirmed/refuted counts) and any ship-with-known-issues findings
- Read key Decisions
- Read the resolved Loops ledger (it leaves the repo with task-context.md in
  step 5 — the PR body is where it survives)
- Get commit log: `git log main..HEAD --oneline`

### 5. Remove task-context.md

Remove task-context.md in a final commit so main stays clean after merge:

```bash
git rm .claude/task-context.md
git commit -m "chore: remove task context for merge"
```

### 6. Push and Create PR

```bash
# Verify remote
git remote -v

# Push branch
git push -u origin HEAD

# Create PR
gh pr create \
  --title "[type](scope): [description from objective]" \
  --body "## Summary
[From task-context.md objective and completion summary]

## Charter
**Objective**: [from task-context.md]
**Non-goals**: [from task-context.md]
**Acceptance**:
[Acceptance list verbatim with final check states — [x] done, [~] waived: reason.
The charter leaves the repo with task-context.md in step 5; this section is
where it survives the merge.]
**Assumptions**:
[Assumptions register verbatim with final states — [x] confirmed, [~] accepted.
Omit the line entirely if the register is empty. These are what the work took
as true without asking; the reviewer should read them as claims to check.]

## Changes
[From git log main..HEAD --oneline]

## Key Decisions
[From task-context.md decisions table]

## Loops
- Linear: [ISSUE-ID | n/a — reason]
- BSpec: [specs/<file>.md | n/a — reason]
- Handoff: [assignee | none]

## External Review
[Only when step 2.7 ran: one summary line — backends run, confirmed/refuted
counts, e.g. 'codex+kimi: 3 confirmed, 2 refuted'. Omit the section if skipped.]

## Known Issues (external review)
[Only when shipping with known issues from step 2.7: one line per finding —
severity, file:line, summary. Omit the section otherwise.]

## Testing
[Verification results from step 2]"
```

### 6.5. Update Linear

Delegate to the `linear-project-manager` subagent (per
`~/.claude/rules/documentation-channels.md`):
- Comment on the issue: outcome summary + PR URL (+ BSpec doc path if one was
  written).
- Move the status: **In Review** now that the PR is open (**Done** if this was
  a direct merge).

Skip only if the ledger says `Linear: n/a — <reason>`.

### 7. Persist what's durable

- If the task produced a **decision** worth keeping → add an ADR to
  `.claude/memory/decisionLog.md`.
- If it surfaced a **project-specific convention or lesson** → add it to
  `.claude/memory/conventions.md`.
- The task's own progress/state lived in `.claude/task-context.md` (removed in
  step 5 for merge) and in native auto-memory — nothing else to update. There
  is no progress/activeContext/sessionHistory to touch.

### 8. Report

Only report Task Complete when **every** Loops entry is resolved or
explicitly waived — an OPEN entry means the task is not done — **and every
Acceptance item is `[x]` or `[~] waived: <reason>`** (the gate from step
2.6; an unchecked item means the task is not done) **and every Assumption is
`[x] confirmed:` or `[~] accepted:`** (the gate from step 2.6b; an
`[ ] assumed:` entry means an unverified claim is shipping unflagged).

```
Task Complete

Branch: [name]
PR: [URL]
Commits: [count]
Verification: [pass/fail summary]
Acceptance: [n checked / m waived / 0 open]
Assumptions: [n confirmed / m accepted / 0 open | none recorded]
External review: [backends + confirmed/refuted counts | skipped — reason]
Linear: [ISSUE-ID → In Review | n/a — reason]
BSpec: [specs/<file>.md | n/a — reason]
Handoff: [assignee | none]

Task context captured in PR description.
Durable decisions/conventions persisted (if any).

Next: Review and merge the PR, then delete the remote branch.
(After merge: move the Linear issue to Done.)
```

---

## Alternative: Direct Merge (if user requests)

If the user explicitly asks for a direct merge instead of a PR:

```bash
git checkout main
git pull origin main
git merge --no-ff [branch] -m "Merge [branch]: [description]"
# task-context.md already removed in step 5
git push origin main
git branch -d [branch-name]
```

Skip PR creation. Still update Memory Bank, and still close the loops:
Linear moves straight to **Done** (comment with the merge commit), BSpec and
Handoff entries resolved as in step 2.5. The Acceptance gate (2.6) and the
external review offer (2.7) still apply — a direct merge does not bypass them.

---

## If Verification Fails

Do NOT proceed with PR/merge. Instead:
1. Report which checks failed
2. Suggest fixes
3. User can re-run `/task-done` after fixing
