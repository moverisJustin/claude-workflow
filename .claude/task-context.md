# Task Context

## Branch
**Name**: claude/multi-model-code-review-e407ef
**Created**: 2026-07-18
**Author**: Justin @ Moveris
**Base**: main @ 752fb28
**Issue**: [Linear — see Loops]

## Objective
Evolve the Boris workflow into multi-model orchestration: Claude stays the
orchestrator/planner; foreign models (Codex CLI, Kimi via OpenRouter) provide
decorrelated review at plan-stage (human-gated, complexity-triggered) and
PR-stage (strength-routed), judging against one central Task Charter. Motivated
by Codex independently finding many real issues in Claude-built Mira finance
code that same-family review missed. Full spec: the approved plan (BSpec ARC
doc per Loops) — plan itself was Codex-reviewed (11 findings, 0 refuted).

## Non-goals
- No autonomous daemons/watchdogs; every gate stays human
- No backends beyond Codex + Kimi in v1 (config makes more a data change)
- No unattended foreign writes — opt-in, per-instance, Claude-reviewed only
- No Orca integration changes

## Acceptance
- [ ] Offline test suites green (foreign-review, validate-findings, review-pack,
      review-merge, memory-context charter additions, drift-check, maintenance)
- [ ] Codex smoke test: fixture pack → schema-valid findings JSON
- [ ] OpenRouter smoke test: cheap model + Kimi model id confirmed (needs
      Justin's API key)
- [ ] Plan-gate dry run: /plan-review on a scratch plan end-to-end
- [ ] PR-review dry run: planted defects caught, report renders with
      attribution + calibration footer
- [ ] Docs updated (README, CHEATSHEET, CLAUDE.md, rules); BSpec ARC authored
      and validated; PR opened

## Plan
- [ ] Phase 1: Task Charter + charter-first packs (memory-context.sh, task-branch
      template, touchpoint skills, drift-check lint)
- [ ] Phase 2: foreign-review.sh + validate-findings.mjs + tests
- [ ] Phase 3: /plan-review skill (schema, reviewer prompt, gate flow)
- [ ] Phase 4: /cross-review pr mode (routing config, review-pack.sh,
      review-merge.mjs, prompts, task-done gate, foreign write path)
- [ ] Phase 5: right-sizing policy, memory write-back invariant, calibration
      ledger, docs sweep
- [ ] Verification: suites + smoke tests + dry runs; single PR

## Loops
- **Linear**: n/a — personal workflow tooling repo (no Linear project)
- **BSpec**: specs/ARC-multi-model-orchestration-v1.md — to author this session
  from the approved plan (OPEN until validated)
- **Handoff**: none
- **External review**: plan reviewed by codex (gpt-5.6-sol) 2026-07-18 —
  11 findings: 8 accepted, 3 partial, 0 refuted; kimi skipped (no key yet)

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-18 | Charter = tightened task-context.md contract, not a new file | A new file would be a 4th source of truth; task-context already flows into every pack |
| 2026-07-18 | One backend-agnostic runner (foreign-review.sh), fail-loud, never substitutes | A missing reviewer reported loudly beats a silently faked review |
| 2026-07-18 | Plan gate runs INSIDE plan mode, complexity-triggered | One approval covers the reconciled plan; boris fires on nearly everything so an always-on gate would be noise |
| 2026-07-18 | Codex emits shared schema directly; native reviews are prerequisites outside merge/stats | [ext-review codex:MMO-006/007] — merge input always schema-valid; report never overclaims coverage |
| 2026-07-18 | Foreign/subagents PROPOSE, main Claude performs all persistent memory writes | [ext-review codex:MMO-010] — single enforceable invariant; opt-in worktree edits are proposals until Claude commits |
| 2026-07-18 | Calibration ledger events versioned (model id, prompt hash, schema ver); routing changes stay human | [ext-review codex:MMO-011] — pooled unversioned cohorts can't support evidence-based routing |

## Progress
### Done
- Plan researched (3 design agents), reconciled, Codex-reviewed (dogfood of the
  gate itself), approved by Justin 2026-07-19

### In Progress
- Parallel build of all 5 phases via workflow fan-out

### Next
- Gates → review → fix → phase commits → smoke tests → BSpec ARC → PR
