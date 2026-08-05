---
name: memory-init
description: Initialize the Memory Bank for a project - the structured, human-authored files native auto-memory does not provide (project identity, ADRs, project-specific conventions) plus the project config.
disable-model-invocation: true
---

# Initialize Memory Bank

The Memory Bank holds only what native auto-memory cannot: **structured,
human-authored** project knowledge. Session continuity ("where was I", recent
work, rolling summaries) is handled by native auto-memory (`MEMORY.md` + topic
files, loaded every session) and session resume — so this skill does NOT create
activeContext/progress/sessionHistory or a context router. It creates three
durable files plus the project config.

## 1. Check current state

Use Glob to check whether `.claude/memory/*.md` already exists. If it does, jump
to "If Memory Bank already exists" at the bottom.

## 2. Create structure + project config

```bash
mkdir -p .claude/memory .claude/audit
```

Ask (or detect from `.git/` and README):
- Does this project use git? (default: yes if `.git/` exists)
- One-line project description?

Create `.claude/project-config.json`:
```json
{
  "git_enabled": true,
  "project_description": "[from user or README]",
  "created": "[today's date]"
}
```
`git_enabled: false` suppresses the git guards and branch info in the hooks;
`true` (default) keeps the full safety net active.

## 3. Analyze the project

Gather from: package.json / pyproject.toml (name, scripts), README, directory
structure, CLAUDE.md if present, git history.

## 4. Create the three Memory Bank files

**projectContext.md** — what this project is and why (durable identity):
```markdown
# Project Context

## Identity
**Name**: [from manifest or directory]
**Purpose**: [from README or infer]
**Repository**: [from git remote]

## Tech Stack
| Layer | Technology |
|-------|------------|
| Language | [detect] |
| Framework | [detect] |
| Testing | [detect] |

## Architecture Overview
[Based on directory structure]

## Key Directories
[Main directories and their purposes]
```

**decisionLog.md** — architecture decisions with rationale (ADRs):
```markdown
# Decision Log

## [Today's Date] - Initialize Memory Bank
### Status
Accepted
### Decision
Use the Memory Bank for structured project knowledge; rely on native
auto-memory for session continuity.
### Rationale
Structured ADRs, project identity, and project-specific conventions have no
native equivalent; session state does.
```

**conventions.md** — project-specific conventions and lessons (the
lesson-capture target for THIS repo; universal lessons go to
`~/.claude/lessons/learned-patterns.md` instead):
```markdown
# Conventions & Lessons

## Code Style
[From CLAUDE.md or detected]

## File Organization
[From directory structure]

## Testing Patterns
[From test files if present]

## Lessons (project-specific)
[Grows as you correct Claude — format: ### short title + what/why/instead]
```

## 5. Report

```
Memory Bank Initialized

Created:
- .claude/project-config.json
- .claude/memory/projectContext.md   (project identity)
- .claude/memory/decisionLog.md      (ADRs)
- .claude/memory/conventions.md      (project-specific lessons)

Session continuity is handled by native auto-memory (/memory to inspect) and
session resume — no activeContext/progress/sessionHistory files needed.
Branch task state lives in .claude/task-context.md (created by /task-branch,
committed for cross-machine handoff).

Use /session-start to orient, /session-end to save, /drift-check to validate.
```

---

## If Memory Bank already exists

If the project still has retired files from an older layout
(`activeContext.md`, `progress.md`, `sessionHistory.md`, `ROUTER.md`,
`patterns/`), offer to fold their still-useful content into the three durable
files (decisions → decisionLog, lessons → conventions) and note that native
auto-memory now carries session state — then leave the retired files for the
user to delete. Do not recreate them.
