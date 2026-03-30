---
description: Load task-specific context mid-session using the Router. Use when switching task types without restarting the session.
---

# Load Context

## Usage
```
/load-context <task-type>
```

## How It Works

1. Read `.claude/memory/ROUTER.md` to get the routing table
2. Match `$ARGUMENTS` against the Task Signal column
3. Load only the matched files (plus the Always Load files if not already in context)

## Supported Task Types

These map directly to the ROUTER.md routing table:

| Shorthand | Matches Route | Loads |
|-----------|--------------|-------|
| `feature` | new feature, implement, build, add | conventions.md, projectContext.md, patterns/INDEX.md |
| `debug` | bug fix, debug, investigate, error | conventions.md, decisionLog.md |
| `test` | test, spec, coverage | conventions.md, patterns/INDEX.md |
| `refactor` | refactor, simplify, clean up | conventions.md, projectContext.md, decisionLog.md |
| `architecture` | architecture, design, plan | projectContext.md, decisionLog.md, conventions.md |
| `deploy` | deploy, CI, release | conventions.md, projectContext.md |
| `review` | review, audit | conventions.md, decisionLog.md, projectContext.md |
| `docs` | docs, README | projectContext.md, progress.md |
| `all` | (special) | Load ALL Memory Bank files |

## Execution

1. If `$ARGUMENTS` is empty, ask: "What type of work are you switching to?"
2. If `$ARGUMENTS` is `all`, load every file in `.claude/memory/` (equivalent to old behavior)
3. Otherwise, match against the shorthand table above or the full ROUTER.md routing table
4. Read the matched files using the Read tool (parallel reads)
5. If patterns/INDEX.md is loaded and a pattern matches the current task, also load that specific pattern file
6. Report what was loaded:

```
Context Loaded: [task-type]
Files: conventions.md, projectContext.md, patterns/INDEX.md
Patterns matched: [pattern name] (if any)
```

## Notes
- This does NOT re-run session-start. It just loads additional context files.
- Files already in context from session-start are not re-read (skip duplicates).
- If ROUTER.md doesn't exist, loads the fallback set: activeContext.md, conventions.md, projectContext.md
