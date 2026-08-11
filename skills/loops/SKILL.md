---
name: loops
description: One board of everything still open — Loops ledger (Linear/BSpec/Handoff), running background tasks/forks/workflows, open PRs, worktrees, stashes, uncommitted work, armed gates. Run it whenever you wonder "what's still in flight?"
allowed-tools: Bash(git status:*), Bash(git stash:*), Bash(git worktree:*), Bash(git branch:*), Bash(gh pr:*), Read, Glob, TaskList
---

# Loops — what's still open?

Gather every category in parallel, then render ONE compact board. Empty
categories get one line ("none"), not a section.

## Gather

1. **Ledger** — read `.claude/task-context.md` → the `## Loops` section
   (Linear / BSpec / Handoff / Forge). Missing section on a feature branch =
   itself an open loop; say so. A missing `**Forge**` line on an older
   task-context is a vacuous pass, not a defect.
2. **Delegated work** — `TaskList`: running/queued background tasks, forks,
   agents, workflows, with age. Anything running >30 min with no output is
   flagged "check on this".
3. **Git** — `git status --short` (uncommitted), `git stash list`,
   `git worktree list` (parallel instances — Orca and Claude worktrees show
   here), and local branches never merged into the repo's real base branch:
   ```bash
   git branch --no-merged "$(bash ~/.claude/scripts/resolve-base-branch.sh --base)"
   ```
4. **PRs** — `gh pr list --author "@me" --state open` (title, age, review
   state). A PR approved but unmerged, or open >3 days, gets flagged.
5. **Gates** — `.claude/audit/verify-gate` exists → the /checks gate is still
   armed.
5b. **Forge** (silent when the project has no forge repo):
   ```bash
   bash ~/.claude/scripts/forge-bridge.sh pending
   ```
   Unpushed shared context is an open loop — a teammate can't see what hasn't
   been pushed. Also flag any teammate blocker or ACTIVE deprecation that
   touches this branch's surface.
6. **Tracker** (only if Linear tools are connected) — In Progress issues
   assigned to me whose branches show no activity; stale In Review issues.

## Render

```
Open loops

Ledger (<branch>): Linear MOV-123 (In Progress) | BSpec OPEN | Handoff none | Forge published
Forge: 2 unpushed entries  ← teammates can't see these yet
Delegated: 2 running (research-agent 4m, ci-watch 12m) | 1 needs collection
Git: 3 uncommitted | 1 stash | 2 worktrees | 1 unmerged branch (fix/foo)
PRs: #23 open 2d (awaiting review)
Gates: none armed
Linear: MOV-118 In Progress, no branch activity 6d  ← stale?

Next: [the single most important loop to close now]
```

**A question waiting on the user is an open loop.** If `## Open decision` in
`.claude/task-context.md` is anything but `None.`, print it verbatim above the
board, under the heading `Waiting on you`. Do not summarize it: it is already
written as a decision brief with the options and the default, and paraphrasing
drops exactly the parts needed to answer.

End with **one** recommended next action, not a lecture. If everything is
closed, say exactly that: "No open loops."
