# Documentation Channels

Every piece of work is documented the same way, across the same channels, no
matter how the session started (`/boris`, `/task-branch`, `/fix-issue`, or
ad-hoc). Two channels plus an explicit handoff, tracked in one ledger. A loop
that isn't closed OR explicitly waived is a defect.

## The contract

1. **Linear is the tracking channel.** Every task maps to a Linear issue:
   - **Start**: search for an existing issue first (all statuses — never create
     duplicates); create one only if none exists. Move it to In Progress and
     record its ID in the Loops ledger.
   - **Link**: tie the PR to the issue on purpose — attach the PR URL to the
     issue AND let the GitHub integration link them (issue ID in the branch
     name, or a magic word like "Closes MOV-123" in the PR description). The
     linkage is valuable: the PR shows on the issue and statuses move on
     their own. The watcher below reconciles it; don't avoid it.
   - **Boundaries** (session end, phase completion): comment progress on the
     issue — what moved, what's next.
   - **Watcher** (at `/session-start`, `/loops`, `/session-end`): reconcile
     ledger issues against real PR state (`gh pr view <n> --json
     state,mergedAt`). An issue whose PR merged but isn't Done gets closed
     with an outcome comment — including one a GitHub automation regressed
     to In Progress after it was Done. An issue marked Done whose PR is
     still open gets flagged, not silently trusted.
   - **Done**: comment the outcome (summary + PR URL) and move the status.
     Status follows the PR: **In Review when the PR opens; Done only after
     the merge is verified** (`gh pr view <n> --json state,mergedAt` — verify
     even when a merge is reported verbally before flipping the status).
     Never set Done manually while a linked PR or branch is still active:
     Linear's automations fire on later push/review events and will regress
     it to In Progress, reopening a closed loop. Where the merge→Done
     automation is configured, let it close the issue; the watcher catches
     everything it misses.
   - Delegate Linear operations to the `linear-project-manager` subagent to
     keep the main context clean.
   - No Linear workspace/team for this work? Record `Linear: n/a — <reason>`
     in the ledger. Silence is not a valid state.

2. **BSpec is the documentation channel.** Any saved spec, PRD, architecture
   doc, or decision record is authored in BSpec format via `/bspec-doc` —
   never freeform markdown:
   - **Start (planning)**: if the task introduces a feature, an architecture
     change, or a non-obvious decision, the plan's durable form is a BSpec doc
     (FEA/ARC/DEC/…). Ephemeral plan-mode text stays ephemeral; the spec is
     the record.
   - **Done**: resolve the ledger's BSpec entry — a doc path, or
     `n/a — <reason>` (trivial fix, no durable design content).
   - Memory Bank boundary: `.claude/memory/decisionLog.md` stays the quick ADR
     *index*; a substantial decision gets a BSpec DEC doc, and the decisionLog
     entry links to it.

3. **Handoff is explicit.** Work passed to someone else means a Linear
   assignment plus a context comment (what's done, what's left, where the spec
   lives) — never a verbal "someone should…".

## The Loops ledger

`.claude/task-context.md` carries the ledger:

```markdown
## Loops
- **Linear**: [ISSUE-ID + status | n/a — reason | OPEN]
- **BSpec**: [specs/<file>.md | n/a — reason | OPEN]
- **Handoff**: [person/team + issue link | none]
```

`OPEN` means unresolved. `/task-done` must not report complete while any entry
is OPEN — resolve it or waive it with a reason. `/session-end` reports OPEN
entries into task-context so the next session starts with the leaks visible.
If a task-context predates the ledger, backfill the section instead of
skipping it.
