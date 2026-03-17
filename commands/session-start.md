---
description: Start a new session by loading Memory Bank context, checking project status, and orienting Claude to continue work seamlessly
---

# Session Start

## Step 0: Check for Memory Bank

!`ls .claude/memory/projectContext.md`

**If `.claude/memory/` does not exist or is empty**, auto-initialize by running `/memory-init` now. Then continue with step 1 below.

## Step 1: Load Memory Bank

Read these files (skip any that don't exist):

1. `.claude/memory/projectContext.md` — what this project is
2. `.claude/memory/activeContext.md` — last session state
3. `.claude/memory/progress.md` — task tracking
4. `.claude/memory/conventions.md` — learned patterns
5. `.claude/memory/sessionHistory.md` — session log
6. `.claude/task-context.md` — branch-specific task (if on a feature branch)

## Step 2: Check Project Status

!`pwd`

Check git status by running these commands (skip any that fail — the working directory may not be a git repo):

1. `git status --short` — uncommitted changes
2. `git branch --show-current` — current branch
3. `git log --oneline -5` — recent commits

If not in a git repo, note that and proceed with Memory Bank context only.

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
