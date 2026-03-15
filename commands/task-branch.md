---
description: Create a feature branch with task context. Initializes .claude/task-context.md for cross-machine handoff.
---

# Create Task Branch

## Current State
!`git branch --show-current 2>/dev/null; true`
!`git status --short 2>/dev/null; true`

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

```bash
# Ensure main is up to date
git checkout main
git pull origin main 2>/dev/null || true

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
**Base**: main @ [short SHA of main]
**Issue**: [#number if detected from branch name, or N/A]

## Objective
[If user provided description beyond branch name, use it here. Otherwise: "Describe the objective of this task."]

## Plan
- [ ] [To be defined]

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

### 4. Commit Task Context

```bash
mkdir -p .claude
# [write task-context.md]
git add .claude/task-context.md
git commit -m "chore: initialize task context for [branch name]"
```

### 5. Report

```
Task Branch Created

Branch: [name]
Base: main @ [SHA]
Task context: .claude/task-context.md

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
