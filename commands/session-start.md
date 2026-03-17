---
description: Start a new session by loading Memory Bank context, checking project status, and orienting Claude to continue work seamlessly
---

# Session Start

## Memory Bank Loading...

### Project Context
!`cat .claude/memory/projectContext.md`

### Active Context (Last Session State)
!`cat .claude/memory/activeContext.md`

### Progress Status
!`cat .claude/memory/progress.md`

### Conventions / Lessons
!`cat .claude/memory/conventions.md`

### Recent Session
!`cat .claude/memory/sessionHistory.md`

### Task Context (Branch-Specific)
!`cat .claude/task-context.md`

## Project Status

!`pwd`
!`git status --short`
!`git branch --show-current`
!`git log --oneline -5`

## Environment Check
!`python3 --version`

---

## Session Initialization Protocol

### 1. Synthesize Context

From Memory Bank, understand:
- **Project**: What is this and what's its purpose?
- **Last Session**: What was being worked on?
- **Current Focus**: From activeContext.md
- **Pending Items**: From progress.md
- **Task Context**: If `.claude/task-context.md` exists, this branch has a specific task. Load its objective, plan, progress, and decisions. This takes priority over activeContext.md for understanding "what to work on."

### Legacy Support
If this project uses `tasks/` instead of `.claude/memory/`:
- `tasks/handoff.md` → treat as activeContext
- `tasks/todo.md` → treat as progress
- `tasks/lessons.md` → treat as conventions
Suggest running `/memory-init` to migrate.

### 2. State Summary

Report to user:
```
Memory Bank Loaded

Project: [Name from projectContext]
Last Session: [Date and summary from sessionHistory]
Last Working On: [From activeContext]
Task Branch: [Name + objective from task-context.md, or "None (on main)"]
Pending Tasks: [Count from progress]
Current Branch: [Git branch]
Uncommitted Changes: [Yes/No]

Ready to continue where you left off.
```

### 3. Update Active Context

Mark session start:
- Record start timestamp
- Note current branch
- Update session state

### 4. Suggest Next Actions

Based on context:
- If on a task branch with task-context.md: continue the task plan
- If on main with no active task: suggest creating a task branch (`/task-branch <name>`)
- Continue last session's work?
- Address pending items?
- Review open issues?
- Start something new?

---

## Quick Actions

- **Continue last task**: Pick up where you left off
- **Check progress**: `/progress`
- **Review decisions**: Look at decisionLog.md
- **Start fresh**: "What would you like to work on?"

---

**Tip**: End sessions with `/session-end` to preserve context for next time.
