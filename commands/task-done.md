---
description: Complete a task branch - verify, create PR, and clean up task-context.md for merge.
---

# Complete Task Branch

## Current State
!`git branch --show-current 2>/dev/null; true`
!`git status --short 2>/dev/null; true`
!`cat .claude/task-context.md 2>/dev/null | head -30; true`

---

## Task Completion Protocol

### 0. Pre-flight Checks

- Confirm we are **NOT on main/master**. If we are, abort: "Cannot run /task-done on main. Switch to your task branch first."
- If `.claude/task-context.md` does not exist, warn but continue: "No task-context.md found. Proceeding without task context."

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

```bash
# Run whatever verification the project supports
npm test 2>/dev/null || python -m pytest 2>/dev/null || echo "No test runner detected"
npm run typecheck 2>/dev/null || python -m mypy . 2>/dev/null || true
npm run lint 2>/dev/null || python -m ruff check . 2>/dev/null || true
npm run build 2>/dev/null || true
```

If any critical checks fail (tests), stop and fix before proceeding.

### 3. Commit Any Remaining Changes

```bash
git add -A
git status --short
# If there are uncommitted changes, commit them with conventional message
```

### 4. Prepare for PR

Capture task context for the PR body:
- Read Objective from task-context.md
- Read Completion Summary
- Read key Decisions
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

## Changes
[From git log main..HEAD --oneline]

## Key Decisions
[From task-context.md decisions table]

## Testing
[Verification results from step 2]"
```

### 7. Update Memory Bank

**Update `.claude/memory/progress.md`:**
- Move the task to "Completed" section

**Update `.claude/memory/activeContext.md`:**
- Clear branch-specific context
- Note the task completion and PR

**Append to `.claude/memory/sessionHistory.md`:**
- Task completion entry with branch name and PR link

### 8. Report

```
Task Complete

Branch: [name]
PR: [URL]
Commits: [count]
Verification: [pass/fail summary]

Task context captured in PR description.
Memory Bank updated.

Next: Review and merge the PR, then delete the remote branch.
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

Skip PR creation. Still update Memory Bank.

---

## If Verification Fails

Do NOT proceed with PR/merge. Instead:
1. Report which checks failed
2. Suggest fixes
3. User can re-run `/task-done` after fixing
