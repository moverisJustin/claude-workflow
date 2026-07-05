# Task Context — feature/phase3-memory-hybrid

## Objective
Boris v3 upgrade, **Phase 3: memory hybrid** (fifth PR). Stacked on the
phase2b branch (PR #8 not yet merged — it shares session-start/install.sh/
drift-check; the PR diff narrows to Phase 3 once #8 merges to main).

Keep the structured, human-authored Memory Bank; delegate session continuity
to native auto-memory (which the repo was hand-rolling).

## Changes
- **Deleted** (redundant with native auto-memory / session resume): the
  ROUTER context-router + pattern-index templates (`context/`), the
  `load-context` skill, and — as concepts across skills/hooks/drift-check —
  activeContext.md, progress.md, sessionHistory.md, patterns/, the GROW step.
- **Memory Bank slimmed to 3 durable files**: projectContext (identity),
  decisionLog (ADRs), conventions (project-specific lessons). memory-init,
  session-start, session-end, and the memory-bank agent all rewritten to the
  hybrid model. session-start is now "deep orient" (the SessionStart hook is
  the automatic boot path); session-end persists only new decisions/
  conventions + task-context; GROW patterns → "capture as a skill".
- **hook-session-start.sh**: stopped reading activeContext.md (native memory
  carries session state); still surfaces the task-context objective.
- **drift-check.sh retargeted**: check_branches → task-context.md only;
  check_paths → surviving memory files + CLAUDE.md + `.claude/rules/*.md`;
  staleness skips durable projectContext/decisionLog; sessionHistory special-
  case removed.
- **Agent memory**: `memory: project` + guidance added to test-writer,
  doc-generator, code-architect, oncall-guide (learn this repo over time).
- **install/uninstall**: retired context-template phase → removes old
  `~/.claude/context/` on upgrade; CONTEXT_COUNT removed.
- Docs (README/CHEATSHEET/CLAUDE.md) rewritten: Memory Bank = 3 structured
  files + native auto-memory; new Agent Memory section; Context Router / Task
  Patterns sections removed; skills count 17→16; SessionStart hook desc fixed.

## Verification
- test-hooks 36/36, test-sync-lessons 17/17, test-install 22/22, drift-check
  runs, installers `bash -n` — all /bin/bash 3.2.

## Next (plan: ~/.claude/plans/calm-skipping-thunder.md)
Phase 4: /ci-loop → /loop; community-agent trim + model tiers (haiku/sonnet/
opus/fable per agent — frontmatter contract confirmed); permissions overhaul;
plugin packaging; scheduled maintenance routine.
