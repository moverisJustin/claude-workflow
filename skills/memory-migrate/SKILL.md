---
name: memory-migrate
description: Convert a project's pre-v3 Memory Bank (activeContext/progress/sessionHistory/ROUTER/patterns or the older tasks/ layout) to the v3 model — salvage decisions and lessons into the 3 durable files, archive the retired ones. Safe and reversible.
---

# Memory Migrate

Convert an old-layout Memory Bank to the v3 model **without losing anything**.
The SessionStart hook surfaces this when it detects retired files; run it once
per dormant project. It is safe: retired files are ARCHIVED, never deleted, and
the durable files are only appended to.

## 1. Detect

Glob `.claude/memory/` and the project root for retired-layout files:
- v2 Boris: `activeContext.md`, `progress.md`, `sessionHistory.md`, `ROUTER.md`, `patterns/`
- older `tasks/` layout: `tasks/handoff.md`, `tasks/todo.md`, `tasks/lessons.md`

If none exist: report "Already on the v3 memory model — nothing to migrate" and stop.

If `.claude/memory/` doesn't exist at all: this project has no Memory Bank; run
`/memory-init` instead.

## 2. What carries over untouched

`projectContext.md`, `decisionLog.md`, `conventions.md` are the **same** in v2
and v3 — leave them in place. If any is missing, create it (see `/memory-init`
for the templates) so salvaged content has a home.

## 3. Salvage (conservatively) into the durable files

Read the retired files and move ONLY genuinely durable knowledge — do not copy
stale session state:

| Retired file | Salvage | Into |
|---|---|---|
| `decisionLog` entries already there | (stays — it's durable) | — |
| architectural **decisions** mentioned in `activeContext`/`sessionHistory`/`tasks/handoff` | as ADR entries | `decisionLog.md` |
| project **conventions / lessons / gotchas** in `activeContext`/`conventions`/`tasks/lessons` | as `### title` + what/why/instead | `conventions.md` |
| `progress`/`todo` items, "current focus", session summaries, "next steps" | **skip** — this is session state; native auto-memory + `task-context.md` own it now | (discard) |
| `patterns/*.md` (reusable step-by-step guides) | if still useful, propose recreating as a **skill** (`skills/<name>/SKILL.md`); otherwise archive | (skill or archive) |
| `ROUTER.md` | nothing — routing is retired (native auto-memory indexes itself) | (archive) |

Append salvaged items; never overwrite existing durable content. When in doubt
whether something is a durable decision/lesson vs stale state, ask or skip it.

## 4. Archive the retired files (reversible)

Move the retired files aside rather than deleting them, so the migration can be
undone:

```bash
ARCHIVE=".claude/memory/archive/pre-v3-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE"
for f in activeContext.md progress.md sessionHistory.md ROUTER.md; do
  [ -f ".claude/memory/$f" ] && mv ".claude/memory/$f" "$ARCHIVE/"
done
[ -d ".claude/memory/patterns" ] && mv ".claude/memory/patterns" "$ARCHIVE/"
# older tasks/ layout, if present
for f in tasks/handoff.md tasks/todo.md tasks/lessons.md; do
  [ -f "$f" ] && mkdir -p "$ARCHIVE/tasks" && mv "$f" "$ARCHIVE/tasks/"
done
```

`.claude/memory/` is gitignored, so this is a local-only move — nothing to commit.

## 5. Report

```
Memory migrated to v3

Kept (durable): projectContext.md, decisionLog.md, conventions.md
Salvaged: [N decision(s) -> decisionLog, M lesson(s) -> conventions, or "none"]
Patterns: [recreated as skill /X | archived | none]
Archived: [list] -> .claude/memory/archive/pre-v3-<date>/  (delete when you're sure)

Going forward: session continuity is native auto-memory (/memory to inspect);
branch task state is .claude/task-context.md. No more activeContext/progress/
sessionHistory to maintain.
```
