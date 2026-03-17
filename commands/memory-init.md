---
description: Initialize Memory Bank for a new project. Creates memory structure and populates with project context.
---

# Initialize Memory Bank

## Checking Current State...

!`ls -la .claude/memory/`
!`pwd`
!`ls -la`

## Legacy Migration Check
!`ls tasks/handoff.md tasks/todo.md tasks/lessons.md`

If legacy `tasks/` files exist, offer to migrate:
1. Copy `tasks/handoff.md` content -> `.claude/memory/activeContext.md`
2. Copy `tasks/todo.md` content -> `.claude/memory/progress.md`
3. Copy `tasks/lessons.md` content -> `.claude/memory/conventions.md`
4. Keep `tasks/` as backup until confirmed working

---

## Memory Bank Initialization

### 1. Create Directory Structure

```bash
mkdir -p .claude/memory
mkdir -p .claude/memory/archive
mkdir -p .claude/audit
```

### 2. Analyze Project

Gather context from:
- package.json (name, description, scripts)
- README.md (purpose, setup)
- Directory structure
- CLAUDE.md if exists
- Git history

### 3. Create Memory Files

**projectContext.md** - Populate from analysis:
```markdown
# Project Context

## Project Identity
**Name**: [from package.json or directory]
**Purpose**: [from README or infer]
**Repository**: [from git remote]

## Tech Stack
| Layer | Technology |
|-------|------------|
| Language | [detect] |
| Framework | [detect] |
| Testing | [detect] |

## Architecture Overview
[Describe based on directory structure]

## Key Directories
[List main directories and purposes]
```

**activeContext.md** - Initialize empty:
```markdown
# Active Context

## Current Focus
**Working On**: [Fresh start]
**Branch**: [current branch]
**Started**: [today's date]

## Recent Changes
None yet.

## Next Steps
1. Set up development environment
2. Review project structure
3. Identify first task
```

**progress.md** - Initialize empty:
```markdown
# Progress Tracker

## Current Sprint
**Goal**: [To be defined]

## In Progress
| Task | Progress | Notes |
|------|----------|-------|
| Project setup | 100% | Memory Bank initialized |

## Completed
| Task | Completed |
|------|-----------|
| Memory Bank init | [today] |

## Queued
[To be populated]
```

**decisionLog.md** - Initialize with template:
```markdown
# Decision Log

## [Today's Date] - Initialize Memory Bank

### Status
Accepted

### Context
Setting up persistent memory for Claude Code workflow.

### Decision
Use Memory Bank system with structured markdown files.

### Rationale
Prevents context loss between sessions.
```

**conventions.md** - Populate from CLAUDE.md/project:
```markdown
# Conventions & Patterns

## Code Style
[From CLAUDE.md or detected]

## File Organization
[From directory structure]

## Testing Patterns
[From test files if present]

## Mistakes Log
[Empty - will be populated]
```

**sessionHistory.md** - Initialize:
```markdown
# Session History

## [Today's Date] - Initial Setup

### Duration
New project setup

### What Was Accomplished
- Memory Bank initialized
- Project context captured

### Context for Next Session
Fresh project setup. Ready to begin development.
```

### 4. Report

```
Memory Bank Initialized

Created:
- .claude/memory/projectContext.md
- .claude/memory/activeContext.md
- .claude/memory/progress.md
- .claude/memory/decisionLog.md
- .claude/memory/conventions.md
- .claude/memory/sessionHistory.md

Project detected:
- Name: [name]
- Stack: [detected stack]
- Type: [web app/cli/library/etc]

Memory Bank is ready.
Use /session-start to begin work.
Use /session-end to save context.
```

---

## If Memory Bank Already Exists

```
Memory Bank already exists

Current files:
[list files]

Options:
1. Keep existing (recommended)
2. Reset all files: /memory-reset
3. Update project context only: /memory-refresh
```
