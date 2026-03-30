---
description: Start a new session by loading Memory Bank context, checking project status, and orienting Claude to continue work seamlessly
---

# Session Start

## Step 0: Check for Memory Bank

Check if `.claude/memory/projectContext.md` exists using the Glob tool.

**If `.claude/memory/` does not exist or is empty**, auto-initialize by running `/memory-init` now. Then continue with step 1 below.

## Step 0.5: Check for Context Router

Check if `.claude/memory/ROUTER.md` exists.

- **If ROUTER.md exists** → proceed to Step 1 (routed loading)
- **If ROUTER.md does NOT exist but Memory Bank does** → auto-generate it:
  1. Read `projectContext.md` to understand the project stack and structure
  2. Read `conventions.md` to identify existing patterns and tools
  3. Check which memory files exist and have content (Glob `.claude/memory/*.md`)
  4. Generate a project-tailored `ROUTER.md` based on the template structure below, customizing the routing table for this specific project's stack and patterns
  5. Create `.claude/memory/patterns/` directory and `.claude/memory/patterns/INDEX.md` if they don't exist
  6. Write the generated ROUTER.md to `.claude/memory/ROUTER.md`
  7. Proceed to Step 1

**ROUTER.md template structure** (customize for the project):
```markdown
# Context Router

## Always Load (~150 tokens)
- `.claude/memory/activeContext.md` (resume prompt, current focus)
- `.claude/task-context.md` (if on feature branch)

## Route by Task Type

| Task Signal | Load These Files |
|-------------|-----------------|
| new feature, implement, build, add | conventions.md, projectContext.md, patterns/INDEX.md |
| bug fix, debug, investigate, error | conventions.md, decisionLog.md |
| test, spec, coverage | conventions.md, patterns/INDEX.md |
| refactor, simplify, clean up | conventions.md, projectContext.md, decisionLog.md |
| architecture, design, plan | projectContext.md, decisionLog.md, conventions.md |
| deploy, CI, release | conventions.md, projectContext.md |
| review, audit | conventions.md, decisionLog.md, projectContext.md |
| docs, README | projectContext.md, progress.md |

## Fallback
Load: activeContext.md, conventions.md, projectContext.md

## Current Project State
[Auto-populated from projectContext.md analysis]
```

## Step 1: Load Memory Bank (Routed)

**Read ROUTER.md first** (always loaded, ~200 tokens).

Then classify the user's task/message against the routing table:
- Match keywords from the user's first message against the "Task Signal" column
- If the user provided a task → load only the matched route's files
- If the user's message is a greeting or question without a clear task → load the **Fallback** set
- **Always also load**: `activeContext.md` (first ~50 lines) and `.claude/task-context.md` (if on a feature branch)

If `patterns/INDEX.md` was loaded and a pattern matches the current task, also load that specific pattern file.

Use the Read tool to read the matched files in parallel.

> **Fallback**: If ROUTER.md is missing or unreadable for any reason, fall back to loading ALL files (original behavior):
> 1. `.claude/memory/projectContext.md`
> 2. `.claude/memory/activeContext.md`
> 3. `.claude/memory/progress.md`
> 4. `.claude/memory/conventions.md`
> 5. `.claude/memory/sessionHistory.md`
> 6. `.claude/task-context.md`

## Step 2: Check Project Status

Run `git status --short`, `git branch --show-current`, and `git log --oneline -5` to check project state. Skip if not a git repo.

## Step 2.5: Drift Check (Lightweight)

Run the drift detection script in quiet mode:
```bash
bash .claude/scripts/drift-check.sh --quiet
```

If the script doesn't exist, check `~/.claude/scripts/drift-check.sh` as a fallback. If neither exists, skip this step silently.

- **Score >= 80**: Proceed silently (don't mention it)
- **Score < 80**: Warn the user in the state summary: "Drift detected in Memory Bank (score: X/100). Run `/drift-check` for details."

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
Memory Bank Loaded (routed: [task-type or "fallback"])

Project: [Name from projectContext]
Last Session: [Date and summary from sessionHistory]
Last Working On: [From activeContext]
Task Branch: [Name + objective from task-context.md, or "None (on main)"]
Context Loaded: [list of files loaded via router]
Current Branch: [Git branch]
Uncommitted Changes: [Yes/No]
Drift Score: [X/100 — only show if < 80, otherwise omit]

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
