# Workflow Rules

## Default Orchestration
- Non-trivial dev tasks run the **/boris protocol by default** — auto-invoke it when the user starts describing work; they should never need to type /boris. Trivial fixes and pure questions skip the ceremony (say so).
- Every planning phase runs two checkpoints in order: `/clarify` (ask the user; see Clarify First) then `/anythingelse` — the wildcard's answer depends on the clarifications. Fold a genuinely accretive wildcard answer in (marked as the wildcard suggestion), or note nothing was worth adding.
- To see everything in flight (ledger, delegated tasks/forks, PRs, worktrees, stashes, gates): `/loops`.

## Clarify First
- **Every planning phase runs a clarification checkpoint** — `/clarify` — before `/anythingelse` and before the plan is presented. Sweep the six axes (scope boundary, success criteria, blast radius, data & state, interfaces & consumers, constraints only the user has), then ask in ONE batched `AskUserQuestion` (max 4, highest-leverage first). Anything answerable from the code, Memory Bank, or git history is not a question — go look. Silence is not a pass: the checkpoint ends either in questions or in the explicit line "clarification checkpoint: no material gaps."
- **During execution, a discovered gap STOPS the work and asks.** Do not build on a guess and flag it later. Batch gaps that surface together into one call; that is the only concession. Subagents have no `AskUserQuestion`, so brief every implementer to RETURN the question rather than guess — the main thread surfaces it. An agent that guesses to avoid stalling has broken this rule.
- **Dangerous assumptions are never taken silently, in any mode, at any stage.** Dangerous = destructive/irreversible, outward-facing (push, deploy, publish, send, external API write), security/credentials/permissions, data integrity (migrations, backfills, financial or participant data), cost-incurring, or scope-redefining. "Probably fine" and inferred prior authorization are not answers.
- **Write down what you did not ask.** Every assumption taken without asking goes in the charter's `## Assumptions` register in `.claude/task-context.md` — it rides into the PR body and every foreign-review pack, so it gets audited instead of forgotten. `/task-done` blocks on an open `- [ ] assumed:` entry.
- Trivial work is exempt (pure question, one-line obvious fix, read-only lookup) — say so and skip.

## Plan First
- Enter native plan mode for ANY non-trivial task (3+ steps or architectural decisions). Plan-mode approval is the gate — read-only is enforced by the harness.
- Write detailed specs upfront to reduce ambiguity. Use plan mode for verification steps too, not just building.
- Before presenting a plan that crosses the complexity bar (multi-module, architectural decisions, or financial/data-integrity/security surface), offer the external review gate (`/plan-review`). Reconciliation is Claude's job — verify each foreign finding, then fold it in or refute it; reviewer disagreements get per-item resolution questions before approval. A missing backend is reported, never silently substituted.
- If something goes sideways mid-execution, STOP and re-plan. Don't keep pushing.
- If a diagnosis goes sideways, verify with hard data (logs, stored metrics) before asserting the next theory.

## Delegate
- Use subagents liberally to keep the main context clean: specialist agents (code-architect, test-writer, doc-generator, oncall-guide) for judgment; forks for context-carrying subtasks; background agents for parallel work; `isolation: worktree` when parallel agents mutate files.
- Use native skills where the platform covers the job: `/simplify` (cleanup), `/verify` + `/checks` (verification), `/code-review` (review), `/security-review` (security).
- For fan-out-scale tasks, `/boris` launches the `boris-build` saved Workflow.

## Right-Sized Delegation

| Tier | Work it owns |
|------|--------------|
| haiku | Linear ops, memory-bank curation, git mechanics |
| sonnet | BSpec drafting (doc-generator drafts, main Claude validates + runs bspec-validate.sh), docs/retro, tests, implementers |
| opus | design judgment, incident debugging |
| main context (reserved) | reconciling foreign findings, plan approval, ALL persistent memory writes |

- Rule of thumb: mechanical → haiku; structured authoring against a clear brief → sonnet; judgment/reconciliation → opus/main.
- Doc/Linear ops are single steps — a subagent, not a Workflow. Reach for parallel cheap agents only where fan-out is real (e.g. the task-done closing sweep: doc-generator + linear-project-manager + main-thread memory write-back).

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
- After ANY correction from the user — or a validated cross-model finding (a foreign reviewer caught something real that Claude confirmed): write the pattern to `.claude/memory/conventions.md`.
- Foreign models never write memory files — Claude reconciles, Claude writes. Foreign lessons are proposals until validated.
- Universal lessons (workflow patterns, cross-project pitfalls) also go to the machine-global Learned Patterns file at `~/.claude/lessons/learned-patterns.md`; project-specific ones stay in conventions.md.
- Publishing to the public workflow repo is OPT-IN: `sync-lessons.sh` promotes a lesson only if its block carries a `<!-- shareable -->` marker (placed under its `### ` heading). Untagged lessons never leave the machine.
- Never re-propose approaches conventions.md documents as ruled out.

## Compaction Recovery (Hook-Driven)
- The PreCompact hook snapshots git state to `.claude/memory/compaction-snapshot.md`; the post-compaction hook injects a recovery directive (verify summary against snapshot, update task-context.md with a cognitive handoff).
- `/handoff` can be run manually any time; run it before breaks or task switches. The briefing captures THINKING (why, what failed, hypotheses), not just file lists.
