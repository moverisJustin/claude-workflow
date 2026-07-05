---
name: session-end
description: End a session cleanly - commit or stash work, persist any new decisions/conventions, update the branch task-context, and run a drift check.
disable-model-invocation: true
---

# Session End

Session state ("what happened / where I am") is captured by **native
auto-memory** automatically — this skill handles the things that aren't
automatic: committing work, persisting *structured* knowledge (ADRs,
project-specific conventions), and updating the committed task-context so the
branch resumes cleanly on any machine.

## 1. Handle uncommitted work

```bash
git status --short
git diff --stat
```

- **Ready to ship**: `/checks` then `/commit-push-pr`.
- **Work in progress**: `git commit -m "wip: session checkpoint - [what]"` (or
  `git stash push -m "session-end-<desc>"` if you don't want a commit).

## 2. Persist structured knowledge (only if new this session)

- **New decision / trade-off / architectural choice** → add an ADR entry to
  `.claude/memory/decisionLog.md`.
- **New project-specific convention or a correction worth keeping** → add it to
  `.claude/memory/conventions.md` (format: `### short title` + what/why/instead).
  If it's a *universal* lesson, put it in `~/.claude/rules/learned-patterns.md`
  instead (see `/update-claude-md` for routing), and tag `<!-- shareable -->`
  only if it's safe to publish.
- **A repeatable multi-step procedure emerged** → capture it as a **skill**
  (`skills/<name>/SKILL.md`), not a memory file — skills load on demand and are
  invocable. (This replaces the old GROW/patterns step.)

Skip anything with nothing new. Don't manufacture entries.

## 3. Update task-context (if on a feature branch)

If `.claude/task-context.md` exists:
- Update Progress (mark completed, add new items), append any new Decisions,
  refresh Notes with a resume prompt for the next session.
- Keep the Objective/Plan structure intact.

```bash
git add .claude/task-context.md
git commit -m "chore: update task context - session end"
```

This is the cross-machine handoff — `git pull` the branch elsewhere and resume
with full state.

## 4. Drift check

Run the project-local script if present, else the global one:
```bash
bash .claude/scripts/drift-check.sh --quiet 2>/dev/null \
  || bash ~/.claude/scripts/drift-check.sh --quiet 2>/dev/null \
  || true
```
If this session's own edits dropped the score below 80 (e.g. referencing a file
that was deleted), fix it before finishing. Skip if neither script exists.

## 5. Report

```
Session complete

Committed: [count] | Stashed/WIP: [yes/no]
Persisted: [decisionLog / conventions entries added, or "nothing new"]
Task context: [updated on <branch> / N/A (on main)]
Drift: [X/100]

Resume with /session-start.
```
