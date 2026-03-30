# Context Router

> This is a **template**. When copied to `.claude/memory/ROUTER.md` in a project,
> customize the routing table and project state for that specific project.

## Always Load (~150 tokens)
- `.claude/memory/activeContext.md` — resume prompt, current focus (read first ~50 lines only)
- `.claude/task-context.md` — if on a feature branch (full file)

These two files are loaded **every session regardless of task type**. They answer: "Where was I? What am I working on?"

## Route by Task Type

Match the user's task/message against the **Task Signal** keywords. Load only the files in the matched row, plus the Always Load files above.

| Task Signal | Load These Files | Why |
|-------------|-----------------|-----|
| new feature, implement, build, add, create | conventions.md, projectContext.md, patterns/INDEX.md | Need patterns + project structure to build correctly |
| bug fix, debug, investigate, error, broken, failing | conventions.md, decisionLog.md | Need conventions to avoid known pitfalls + past decisions for context |
| test, spec, coverage, assertion | conventions.md, patterns/INDEX.md | Need testing conventions + any testing patterns |
| refactor, simplify, clean up, reorganize | conventions.md, projectContext.md, decisionLog.md | Need architecture awareness to refactor safely |
| architecture, design, plan, RFC, proposal | projectContext.md, decisionLog.md, conventions.md | Need full project understanding for design work |
| deploy, CI, release, pipeline, Docker | conventions.md, projectContext.md | Need deploy conventions + infrastructure context |
| review, audit, security | conventions.md, decisionLog.md, projectContext.md | Need full context for thorough review |
| docs, README, documentation | projectContext.md, progress.md | Need project identity + what's been done |
| session handoff, context full, /handoff | activeContext.md (full), progress.md, conventions.md | Need complete state for cognitive briefing |

## Fallback
If the task doesn't match any signal above (or the user's first message is a greeting/question without a clear task), load:
- `activeContext.md` (full), `conventions.md`, `projectContext.md`

## Current Project State
<!-- Updated by /session-end. Re-grounds the agent each session. -->
<!-- What is working. What is not yet built. Known issues. -->
<!-- This section is project-specific — fill in after setup. -->

## Notes
- **Files are relative to `.claude/memory/`** unless an absolute path is given
- **Patterns load on demand**: `patterns/INDEX.md` is a registry; the agent reads it, then loads only the matching pattern file for the current task
- **Mid-session switching**: Use `/load-context <type>` to load a different context set without restarting the session
- **ROUTER.md itself is always loaded** — it's the navigation hub (~200 tokens)
