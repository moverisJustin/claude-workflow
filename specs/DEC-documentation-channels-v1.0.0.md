---
id: dec-documentation-channels-001
title: Unified Documentation Channels (Linear + BSpec Loops Ledger)
type: DEC
status: Draft
version: 1.0.0
owner: Justin Keene
domain: engineering-workflow
created: 2026-07-11
updated: 2026-07-11
---

# Unified Documentation Channels (Linear + BSpec Loops Ledger)

## Overview

Decision record for adopting a single documentation contract across the Claude
Code workflow: every task, regardless of entry point, tracks in Linear,
documents in BSpec, and hands off explicitly — enforced by a "Loops ledger" in
the branch task-context.

## Context

The workflow (Boris v3) had exactly one hard loop-closer: the `/checks`
Stop-hook verify gate, which covers only quality gates (tests, types, lint,
format, build). Everything else that constitutes "done" was advisory prose:

- Linear updates were mentioned in learned patterns ("update Linear via
  subagent at phase boundaries") but no skill required them. `/task-done`,
  `/session-end`, and `/boris` shipped work without touching the tracker.
- BSpec documentation (`/bspec-doc`) existed but nothing triggered it at
  planning or completion, so specs were written only when someone remembered.
- Handoff to other people had no structured step at all (`/handoff` covers
  session-to-session continuity, not person-to-person transfer).

The observed failure mode: loops left open unintentionally — work completed in
git but invisible in Linear, decisions made but never written down, handoffs
that existed only verbally. The design lesson from the verify gate applied
here: advice loses to momentum; only enforcement at a boundary closes a loop
reliably.

## Decision

Adopt one documentation contract, defined once in
`rules/documentation-channels.md` (installed always-on to `~/.claude/rules/`),
and wire it into every entry and exit point:

1. **Linear is the tracking channel.** Every task maps to an issue:
   find-or-create (search all statuses first) and move to In Progress at
   branch start (`/task-branch`, `/boris` step 0, `/fix-issue`); progress
   comment at `/session-end`; outcome comment + status move (In Review at PR,
   Done at merge) at `/task-done`. Linear operations are delegated to the
   `linear-project-manager` subagent.
2. **BSpec is the documentation channel.** Any saved spec, PRD, architecture
   doc, or decision record is authored via `/bspec-doc` — never freeform
   markdown. Durable plans for features/architecture changes become BSpec docs
   at planning time (`/boris` step 1); `.claude/memory/decisionLog.md` remains
   a lightweight index that links to substantial BSpec DEC docs.
3. **Handoff is explicit.** Passing work to someone else means a Linear
   assignment plus a context comment.

Enforcement is the **Loops ledger** — a `## Loops` section in
`.claude/task-context.md` with three entries (Linear / BSpec / Handoff), each
either resolved, explicitly waived with a reason (`n/a — <reason>`), or
`OPEN`:

- `/task-done` must not report complete while any entry is OPEN.
- `/session-end` refreshes the ledger and reports OPEN entries forward.
- `/session-start` surfaces OPEN entries in its orientation summary.
- Ledgers missing from older task-contexts are backfilled, not skipped.
- The resolved ledger is copied into the PR body before task-context.md is
  removed for merge, so the record survives the branch.

## Alternatives Considered

- **A loop-gate Stop hook** (same mechanism as the verify gate, armed at
  `/task-branch`, cleared by `/task-done`): deferred. Skill-level enforcement
  is cheap and reversible; the hook adds friction on every turn. Revisit if
  the ledger still leaks in practice.
- **Duplicating the protocol in each skill**: rejected. The contract lives in
  one rule file; skills reference it and add only their boundary-specific
  steps ("the protocol exists in exactly ONE place").
- **Keeping Linear/BSpec advisory**: rejected — that is the status quo that
  produced the open loops.

## Consequences

- Every work instance is documented the same way, across the same channels,
  whether it started as `/boris`, `/task-branch`, `/fix-issue`, or ad-hoc.
- "Done" now has a checkable definition beyond green gates; an OPEN ledger
  entry is a visible defect rather than a silent omission.
- Cost: each task boundary spends one subagent call on Linear and an explicit
  BSpec decision. Waivers (`n/a — <reason>`) keep trivial fixes cheap.
- Risk: ledger discipline in skills is still model-followed, not
  harness-enforced; the deferred Stop-hook gate is the escalation path.

## Affected Components

- `rules/documentation-channels.md` (new — the contract)
- `rules/workflow.md` (Verify Before Done includes the ledger)
- `skills/task-branch`, `skills/task-done`, `skills/session-start`,
  `skills/session-end`, `skills/boris`, `skills/fix-issue`
- `CLAUDE.md`, `README.md` (documented behavior)
