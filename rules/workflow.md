# Workflow Rules

## Default Orchestration
- Non-trivial dev tasks run the **/boris protocol by default** — auto-invoke it when the user starts describing work; they should never need to type /boris. Trivial fixes and pure questions skip the ceremony (say so).
- At the **end of every planning phase** — boris or not — run the `/anythingelse` wildcard checkpoint before presenting the plan; fold a genuinely accretive answer in (marked as the wildcard suggestion), or note nothing was worth adding.
- To see everything in flight (ledger, delegated tasks/forks, PRs, worktrees, stashes, gates): `/loops`.

## Plan First
- Enter native plan mode for ANY non-trivial task (3+ steps or architectural decisions). Plan-mode approval is the gate — read-only is enforced by the harness.
- Write detailed specs upfront to reduce ambiguity. Use plan mode for verification steps too, not just building.
- If something goes sideways mid-execution, STOP and re-plan. Don't keep pushing.
- If a diagnosis goes sideways, verify with hard data (logs, stored metrics) before asserting the next theory.

## Delegate
- Use subagents liberally to keep the main context clean: specialist agents (code-architect, test-writer, doc-generator, oncall-guide) for judgment; forks for context-carrying subtasks; background agents for parallel work; `isolation: worktree` when parallel agents mutate files.
- Use native skills where the platform covers the job: `/simplify` (cleanup), `/verify` + `/checks` (verification), `/code-review` (review), `/security-review` (security).
- For fan-out-scale tasks, `/boris` launches the `boris-build` saved Workflow.

## Verify Before Done
- Never mark a task complete without proving it works. `/checks` runs the stack's real gates and arms a Stop-hook verify gate that holds the turn open until green. `/verify` observes the app actually working.
- `/code-review <effort>` before merging; `ultra` for release branches. `/cross-review` adds a decorrelated second-model-family pass (Codex) — use `design` mode on UI work to catch "looks like AI design" tells.
- Diff behavior between main and your changes when relevant.
- Done includes documentation: the Loops ledger (Linear / BSpec / Handoff) must be resolved or explicitly waived — see `documentation-channels.md`. An OPEN loop means not done.
- Ask: "Would a staff engineer approve this?"

## Autonomous Bug Fixing
- Given a bug report: just fix it. Point at logs, errors, failing tests — resolve them without hand-holding.

## Demand Elegance (Balanced)
- For non-trivial changes, pause and ask "is there a more elegant way?" If a fix feels hacky: implement the elegant solution knowing everything you know now. Skip for simple, obvious fixes.

## Self-Improvement Loop
- After ANY correction from the user: write the pattern to `.claude/memory/conventions.md`.
- Universal lessons (workflow patterns, cross-project pitfalls) also go to the machine-global Learned Patterns file at `~/.claude/rules/learned-patterns.md`; project-specific ones stay in conventions.md.
- Publishing to the public workflow repo is OPT-IN: `sync-lessons.sh` promotes a lesson only if its block carries a `<!-- shareable -->` marker (placed under its `### ` heading). Untagged lessons never leave the machine.
- Never re-propose approaches conventions.md documents as ruled out.

## Compaction Recovery (Hook-Driven)
- The PreCompact hook snapshots git state to `.claude/memory/compaction-snapshot.md`; the post-compaction hook injects a recovery directive (verify summary against snapshot, update task-context.md with a cognitive handoff).
- `/handoff` can be run manually any time; run it before breaks or task switches. The briefing captures THINKING (why, what failed, hypotheses), not just file lists.
