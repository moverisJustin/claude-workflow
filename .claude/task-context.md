# Task Context — feature/phase2-skills-migration

## Objective
Boris v3 upgrade, **Phase 2: commands → skills migration + boris consolidation**
(third PR; Phase 0 = #5, Phase 1 = #6, both merged).

## Changes
- **All 16 remaining commands migrated to `skills/<name>/SKILL.md`** (same `/name`
  invocation — skills are the successor format and win on name conflicts):
  - `disable-model-invocation: true` on side-effectful user-timed skills
    (quick-commit, commit-push-pr, task-branch, task-done, session-end,
    memory-init, fix-issue, ci-loop, anythingelse)
  - `allowed-tools` git grants on quick-commit/commit-push-pr/task-branch/
    task-done (kills the top permission-prompt sources)
  - `argument-hint` on task-branch/fix-issue/load-context/first-principles
  - fix-issue: stale `mcp__claude_ai_Linear__*` hardcoded names replaced with
    capability-level instructions (ToolSearch finds current names); jq-pipe
    backtick simplified. anythingelse: missing description added.
  - `context: fork` evaluated and deferred: candidates (memory-init, handoff,
    session-start) all need main-conversation context or user interaction.
- **Boris consolidated**: `agents/boris.md` + `commands/boris.md` +
  `skills/boris-workflow/` (three drifting copies + the persona-indirection
  hack) → ONE `skills/boris/SKILL.md` (plan mode gate, Agent-tool delegation
  with forks/background/worktrees/SendMessage, native-skill routing table) +
  `workflows/boris-build.js` (saved Workflow: partition into file-disjoint
  items → parallel implement → gates + adversarial per-item review + one fix
  round; NEVER commits/pushes — that stays in the main conversation).
- **install.sh**: installs all skills/ dirs + workflows/; Phase 3.5 removes
  old command flat-copies (derived from skills/ dir, never stale), boris
  agent, boris-workflow skill; backs up skills/. **uninstall.sh**: removes
  repo-derived skills + workflows (list derived at runtime).
- Docs: README/CHEATSHEET/CLAUDE.md — commands → skills language, counts
  (9 core agents, 17 skills, 1 workflow), backtick-sandbox lesson retargeted
  at SKILL.md paths.

## Verification
- Conversion validated by a dedicated agent: 16/16 frontmatter + heading-
  sequence identical to originals; no stale MCP names; no retired-command refs.
- bash -n install.sh/uninstall.sh; full hook + sync-lessons suites.

## Next (plan: ~/.claude/plans/calm-skipping-thunder.md)
- Phase 2b: CLAUDE.md slimming into rules/skills/memory topics + sync-lessons
  retarget. Phase 3: memory hybrid. Phase 4: /ci-loop → /loop, model tiers,
  permissions overhaul, plugin packaging, scheduled maintenance.
