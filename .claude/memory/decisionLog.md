# Decision Log

## 2026-03-15 — Feature branches by default
**Decision**: All work happens on feature branches, not main.
**Rationale**: Safer workflow, enables per-branch task context, cross-machine handoff via git pull.
**Exception**: Initial build phase (<5 commits) can use main.

## 2026-03-15 — task-context.md per branch (committed)
**Decision**: Each feature branch carries `.claude/task-context.md` committed to git.
**Rationale**: Enables cross-machine handoff (just `git pull`), context travels with the branch, removed on merge to main.
**Alternatives rejected**: Storing task context in Memory Bank (doesn't travel with branch), storing in a separate tracking system (adds friction).

## 2026-03-17 — Prose instructions for git commands in session commands
**Decision**: Replace `!` backtick git auto-execute with prose instructions in session-end, session-start, handoff.
**Rationale**: `!` backtick commands fail fatally in non-git directories. Prose instructions let Claude run them via Bash tool with graceful error handling.
**Alternatives rejected**: `git -C` (still fails if no repo exists), `2>/dev/null` (sandbox blocks it).
