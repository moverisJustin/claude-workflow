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

## The Task Charter

`.claude/task-context.md` opens with the **task charter** — `## Objective`
(what + why), `## Non-goals` (scope fence), `## Acceptance` (checkable
criteria), `## Assumptions` (what was taken as true without asking). It is
committed and branch-scoped, and it survives the branch in the PR body's
`## Charter` section.

Precedence:

- The **charter** is the authority on the task's goals and scope. Every
  reviewer — native or foreign — judges the work against it.
- The **BSpec doc** (pointed to by the ledger's `**BSpec**:` line) is the
  authority on durable design detail. The charter points at it; design detail
  is never duplicated into the charter.
- **Linear mirrors the charter, one-way.** A new issue is populated from the
  charter (Objective → Context, Acceptance → Acceptance Criteria, Non-goals →
  Out of Scope). Linking an existing issue backfills its criteria into the
  charter ONCE; after that, edits flow charter → Linear, never back.

Every external review pack embeds the charter verbatim at the top
(`memory-context.sh` enforces this), so all reviewers evaluate against the
same frame.

Acceptance syntax (exact forms — the `/task-done` gate greps them):

- `- [ ]` open
- `- [x]` done
- `- [~] waived: <reason>` waived

Assumptions syntax (same gate, its own forms — see `workflow.md` Clarify
First for when an entry gets written):

- `- [ ] assumed: <what, and what breaks if it's wrong>` unresolved
- `- [x] confirmed: <what — how it was validated>` verified
- `- [~] accepted: <what> — <why living with it is safe>` knowingly accepted

The register is the audit trail for everything not asked about. Reviewers —
native and foreign — treat its entries as **unverified claims to attack**, not
as established facts. A section absent from an older task-context is a
vacuous pass, not a defect; new work gets it from the `/task-branch` template.

Keep the charter cheap — one line per section is fine — but never leave
placeholders. `/task-done` may not report complete while any Acceptance item
is unchecked and unwaived, or while any Assumption is still `- [ ] assumed:`.
A deliberate scope change edits the charter, adds a Decisions row, and syncs
Linear.

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
