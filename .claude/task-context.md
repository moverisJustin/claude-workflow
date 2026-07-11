# Task Context — Linear status convention: link PRs, Done only after verified merge

**Branch**: fix/linear-done-after-verified-merge
**Date**: 2026-07-11

## Task
Manually marking Linear issues Done while their linked PR/branch is still
active lets Linear's GitHub workflow automations regress them to In Progress
on later push/review events — reopening loops that were actually closed
(observed repeatedly in production). The GitHub↔Linear linkage itself is
worth keeping (PR visible on the issue, statuses move on their own), so the
convention keeps the linkage and adds reconciliation on our side. Encoded in
`rules/documentation-channels.md`:

- **Link** the PR to the issue on purpose (attachment + issue ID in branch
  name / "Closes MOV-123" magic word) — don't avoid the automations.
- In Review when the PR opens.
- Done only after the merge is verified (`gh pr view <n> --json
  state,mergedAt`) — verify even when a merge is reported verbally; never
  set Done manually while the PR is still active.
- **Watcher** at `/session-start`, `/loops`, `/session-end`: reconcile ledger
  issues against real PR state — close merged-but-not-Done issues (including
  automation-regressed ones), flag Done issues whose PR is still open.

README documentation-channels blurb updated to match. Installed
~/.claude/rules/ copy mirrored.

## Loops
- **Linear**: MOV-2526 — In Review (PR #25 open, "Closes MOV-2526" in body).
  Done after verified merge.
- **BSpec**: n/a — small process-rule change; rationale in the PR description
  and the rule text itself.
- **Handoff**: none
