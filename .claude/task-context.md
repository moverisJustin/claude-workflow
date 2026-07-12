# Task Context

## Branch
**Name**: claude/memory-persistence-agents-39905d
**Created**: 2026-07-12
**Author**: Justin @ Moveris
**Base**: main @ 7696be2
**Issue**: [Linear — see Loops]

## Objective
Add a reusable "memory context pack" primitive so a foreign agent (Codex today,
local/Orca models next) can be handed this repo's standing memory it can't
auto-load. Motivated by evaluating jaredrhod/ai-memory-vault + jaredrhod.com/rules
(YouTube jZOXRLho_ag): the vault is a less-developed, Claude-Code-centric version
of what we already run, and does NOT solve cross-model persistence. The real gap
is injection, not storage — memory is already model-agnostic markdown; foreign
models just never receive it. `/cross-review` handed Codex only the diff.

## Plan
- [x] `scripts/memory-context.sh` — assembles Memory Bank + task-context +
      learned-patterns (index / --full / --grep), fence-aware, always exit 0
- [x] `scripts/test-memory-context.sh` — 33 guard tests (incl. fence-safety)
- [x] Wire into `skills/cross-review/SKILL.md` (step 0.5 + both modes + verify)
- [x] README + CHEATSHEET "Cross-model memory" sections
- [ ] Linear tracking, commit, PR

## Loops
- **Linear**: n/a — personal workflow tooling repo (no Linear project)
- **BSpec**: n/a — tooling primitive, no durable design doc; decision captured
  in decisionLog.md instead
- **Handoff**: none

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-12 | Don't adopt ai-memory-vault or the 11 rules | We already run a more advanced layered memory; ~10/11 rules already covered. Storage isn't the gap. |
| 2026-07-12 | Build a shell primitive (`memory-context.sh`), not skill-inline instructions | DRY, testable, reusable across any foreign-agent handoff — matches drift-check/bspec-validate pattern |
| 2026-07-12 | learned-patterns default = heading index, not full bodies | 36KB of bodies is too large to prepend to every review; `--full`/`--grep` opt in |
| 2026-07-12 | Pack framed as reference DATA, not instructions | Piping memory into a foreign model is an injection surface; header enforces the boundary |

## Progress
### Done
- Script + tests (33 passing), cross-review wiring, README/CHEATSHEET docs
- Verified: memory-context tests green, maintenance count-check clean

### Next
- Run test-install.sh (confirm new script deploys), Linear issue, commit, PR
