---
description: Start a new session by loading Memory Bank context, checking project status, and orienting Claude to continue work seamlessly
---

# Session Start

## Memory Bank Loading...

### Project Context
!`cat .claude/memory/projectContext.md 2>/dev/null | head -40 || echo "No project context - run /memory-init to set up"`

### Active Context (Last Session State)
!`cat .claude/memory/activeContext.md 2>/dev/null | head -30 || cat tasks/handoff.md 2>/dev/null | head -30 || echo "No active context found - run /memory-init to set up"`

### Progress Status
!`cat .claude/memory/progress.md 2>/dev/null | grep -A 20 "## In Progress\|## Completed" | head -25 || cat tasks/todo.md 2>/dev/null | head -25 || echo "No progress tracking"`

### Recent Session
!`cat .claude/memory/sessionHistory.md 2>/dev/null | head -40 || echo "No session history"`

## Project Status

!`pwd`
!`git status --short 2>/dev/null || echo "Not a git repo"`
!`git branch --show-current 2>/dev/null`
!`git log --oneline -5 2>/dev/null`

## Environment Check
!`node --version 2>/dev/null || echo "Node not found"`
!`cat package.json 2>/dev/null | jq -r '.name + " v" + .version' 2>/dev/null || echo ""`

## Open Issues
!`gh issue list --state open --limit 5 2>/dev/null || echo ""`

## CLAUDE.md Quick Reference
!`cat CLAUDE.md 2>/dev/null | head -30 || echo "No CLAUDE.md"`

---

## Session Initialization Protocol

### 1. Synthesize Context

From Memory Bank, understand:
- **Project**: What is this and what's its purpose?
- **Last Session**: What was being worked on?
- **Current Focus**: From activeContext.md
- **Pending Items**: From progress.md

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
