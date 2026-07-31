---
name: task-branch
description: Create a feature branch with task context. Initializes .claude/task-context.md for cross-machine handoff.
argument-hint: [branch-name]
disable-model-invocation: true
allowed-tools: Bash(git checkout:*), Bash(git switch:*), Bash(git branch:*), Bash(git status:*), Bash(git push:*)
---

# Create Task Branch

## Current State
!`git branch --show-current`
!`git status --short`

---

## Task Branch Protocol

### 1. Parse Arguments

Branch input: $ARGUMENTS

Determine branch name:
- If input starts with `fix/`, `feature/`, or `task/`, use it as-is
- If input starts with a number (issue reference), use `fix/$ARGUMENTS`
- Otherwise, default to `task/$ARGUMENTS`

Slugify the name: lowercase, hyphens for spaces/special chars, max 50 chars.

Examples:
- `/task-branch add-auth` -> `task/add-auth`
- `/task-branch feature/dark-mode` -> `feature/dark-mode`
- `/task-branch fix/login-crash` -> `fix/login-crash`
- `/task-branch 123-fix-header` -> `fix/123-fix-header`

### 2. Create Branch

**Resolve the base branch first — never assume `main`.** Repos differ: `main`,
`master`, and `develop`+`main` gitflow are all common, and branching off the
wrong one is silent (or fails outright where the branch is `master`).

```bash
bash ~/.claude/scripts/resolve-base-branch.sh --explain
```

Show the user the evidence line the first time a repo is resolved (e.g.
"20/20 recent merged PRs targeted `master`") — the answer is then cached in
`.claude/project-config.json` and later runs are silent. If the evidence looks
wrong, set `base_branch` in that file; explicit config always wins.

```bash
BASE=$(bash ~/.claude/scripts/resolve-base-branch.sh --base)
git checkout "$BASE"
git pull origin "$BASE" 2>/dev/null || true

# Create and switch to new branch
BRANCH_NAME="[parsed from step 1]"
git checkout -b "$BRANCH_NAME"
```

### 3. Initialize Task Context

Create `.claude/task-context.md`:

```markdown
# Task Context

## Branch
**Name**: [branch name]
**Created**: [YYYY-MM-DD]
**Author**: [from git config user.name]
**Base**: [resolved base branch] @ [short SHA of that branch]
**Issue**: [#number if detected from branch name, or N/A]

## Objective
[What + why, 1-3 sentences. Use the user's description if they gave one.]

## Non-goals
- [what this task deliberately does NOT do or touch]

## Acceptance
- [ ] [checkable criterion — how we know it's done]

## Assumptions
- [nothing assumed yet — entries land here as work proceeds]

## Plan
- [ ] [To be defined]

## Loops
- **Linear**: OPEN
- **BSpec**: OPEN
- **Handoff**: none
- **Forge**: OPEN

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|

## Progress
### Done
- [nothing yet]

### In Progress
- [nothing yet]

### Blocked
- [nothing blocked]

## Notes
[Context that helps someone picking this up cold]
```

The first four sections — Objective / Non-goals / Acceptance / Assumptions —
are the **task charter**: the authority on this task's goals and scope, which
every review (native or foreign) judges the work against. Keep it cheap: one
line each is fine. Never leave placeholders — fill them from the user's
description, or ask before committing.

Acceptance syntax (exact forms — the `/task-done` gate greps them):
- `- [ ]` open
- `- [x]` done
- `- [~] waived: <reason>` waived

Assumptions syntax (same gate, its own forms — every assumption taken without
asking the user gets an entry; see Clarify First in
`~/.claude/rules/workflow.md`):
- `- [ ] assumed: <what, and what breaks if it's wrong>` unresolved
- `- [x] confirmed: <what — how it was validated>` verified
- `- [~] accepted: <what> — <why living with it is safe>` knowingly accepted

### 4. Link Linear (documentation-channels contract)

Per `~/.claude/rules/documentation-channels.md`, every task maps to a Linear
issue. Delegate to the `linear-project-manager` subagent:
- If the branch name/arguments reference a Linear ID (e.g. `PROJ-123`), use it.
- Otherwise **search existing issues first** (all statuses); create one only
  if none matches the objective.
- **New issue**: populate it from the charter — Objective → issue Context,
  Acceptance → Acceptance Criteria, Non-goals → Out of Scope.
- **Existing issue**: backfill its criteria into the charter ONCE (its
  checkboxes/criteria → Acceptance, its Out of Scope → Non-goals). After that
  the charter is authoritative — edits flow one-way, charter → Linear.
- Move the issue to In Progress.
- Fill the ledger: `**Linear**: PROJ-123 (In Progress)`.

If there is genuinely no Linear workspace/team for this work, set
`**Linear**: n/a — <reason>`. Never leave it OPEN silently at branch creation.

The **BSpec** ledger entry stays OPEN until planning decides: feature /
architecture / non-obvious decision → author the spec with `/bspec-doc`;
otherwise resolve it `n/a — <reason>` (see the rule file).

### 4b. Publish "work starting" to Forge (optional channel)

Per the cadence table in `~/.claude/rules/documentation-channels.md`, work
starting on a branch is a publish trigger. The bridge no-ops silently when the
project has no forge repo, so this runs unconditionally:

```bash
bash ~/.claude/scripts/forge-bridge.sh publish wip "<entry>"
```

Compose the entry from the charter — what you're building, the ticket ID and
one line of why, the branch name, what's next, and any teammate impact you can
already see. Then set the ledger: `**Forge**: <repo> — wip published`, or
`n/a — no forge repo for this project` if the bridge reported none.

### 5. Commit Task Context

```bash
mkdir -p .claude
# [write task-context.md]
git add .claude/task-context.md
git commit -m "chore: initialize task context for [branch name]"
```

### 6. Report

```
Task Branch Created

Branch: [name]
Base: main @ [SHA]
Task context: .claude/task-context.md
Linear: [ISSUE-ID (In Progress) | n/a — reason]

Next steps:
1. Describe your objective (or tell me what you're building)
2. Start implementing
3. Use /session-end to save progress
4. Use /task-done when complete
```

---

## If No Arguments Provided

Ask the user:
- What are you working on?
- Suggest a branch name based on their description
- Offer prefix options: feature/, fix/, task/
