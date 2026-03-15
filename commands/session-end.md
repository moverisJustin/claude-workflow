---
description: End session by saving Memory Bank state, creating session summary, and preserving context for seamless continuation
---

# Session End

## Current State

### Uncommitted Changes
!`git status --short 2>/dev/null || echo "Not a git repo"`
!`git diff --stat 2>/dev/null | tail -10`

### Commits This Session
!`git log --oneline --since="8 hours ago" 2>/dev/null | head -10`

### Files Modified Recently
!`git diff --name-only HEAD~5 2>/dev/null | head -15 || echo ""`

---

## Session Wrap-up Protocol

### 1. Handle Uncommitted Work

**If uncommitted changes exist:**

Option A - Ready to commit:
```bash
# Verify first
/verify-all
# Then commit
/commit-push-pr
```

Option B - Work in progress:
```bash
# Create checkpoint
git stash push -m "session-end-$(date +%Y%m%d-%H%M%S)"
```

Option C - Save as WIP commit:
```bash
git add -A
git commit -m "wip: session checkpoint - [brief description]"
```

### 2. Generate Session Summary

Analyze this session and document:

**What Was Accomplished**
- List completed tasks
- Note features implemented
- Record bugs fixed
- Count commits made

**Key Decisions Made**
- Any architectural choices
- Technical trade-offs decided
- Patterns established

**Files Modified**
- List significant file changes
- Note new files created
- Flag deleted files

### 2.5. Update Task Context (if on feature branch)

If `.claude/task-context.md` exists on this branch:

**Update `.claude/task-context.md`:**
- Update Progress section (mark completed items, add new ones)
- Add any new Decisions made this session
- Update Notes with context for next session
- Do NOT change the Objective or Plan structure

**Commit task-context.md update:**
```bash
git add .claude/task-context.md
git commit -m "chore: update task context - session end"
```

This ensures cross-machine handoff works: just `git pull` on the branch.

### Legacy Support
If this project has `tasks/` files alongside or instead of Memory Bank:
- Also update `tasks/handoff.md` with current state
- Also update `tasks/todo.md` with progress
- Also update `tasks/lessons.md` with new conventions/lessons

### 3. Update Memory Bank

**Update `.claude/memory/activeContext.md`:**
- Current working state
- Files in focus
- Open questions
- Next steps

**Update `.claude/memory/progress.md`:**
- Mark completed items as done
- Add newly discovered tasks
- Update in-progress items

**Append to `.claude/memory/sessionHistory.md`:**
```markdown
## [Today's Date] [Time] - Session Summary

### Duration
[Approximate session length]

### What Was Accomplished
- [Task 1]
- [Task 2]

### Key Decisions Made
- [Decision if any]

### Files Modified
- `path/file.ts` - [change summary]

### Commits Created
- `SHA` message

### Context for Next Session
[Critical info the next Claude needs]

### Open Items
- [ ] [Unfinished work]
- [ ] [Questions to resolve]
```

**Update `.claude/memory/conventions.md`** (if learned something new):
- New patterns discovered
- Mistakes to avoid
- Best practices identified

**Update `.claude/memory/decisionLog.md`** (if significant decision made):
- Add new ADR entry

### 4. Final Checks

Before ending:
- [ ] All work committed or stashed?
- [ ] Memory Bank files updated?
- [ ] Any blockers documented?
- [ ] Push to remote if ready?

### 5. Report to User

```
Session Complete

Duration: [time]
Commits: [count]
Files changed: [count]

Memory Bank Updated:
- activeContext.md - Current state saved
- progress.md - Tasks updated
- sessionHistory.md - Summary added

Task Context: [Updated on branch / Not applicable (on main)]

Work Status:
[All committed / Stashed for later / WIP commit created]

Resume with: /session-start
```

---

## Session Summary Template

```markdown
## Session Summary

### Accomplished
- [What was done]

### In Progress
- [Partially complete work]

### Next Steps
- [What to do next time]

### Blockers
- [Anything blocking progress]

### Notes
- [Any other context]
```

---

**Memory Bank preserves your context.** Next session will pick up right where you left off.
