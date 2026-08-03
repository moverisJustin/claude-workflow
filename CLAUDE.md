<!-- boris-version: 3 — machine-readable upgrade stamp for install.sh; do not remove.
     (HTML comments are stripped before context injection, so this costs zero tokens.) -->
# Session Boot (MANDATORY)

Every session begins with:
1. **Load context**: run the `/session-start` protocol — Memory Bank (`.claude/memory/`), `git status`/branch/recent commits, `.claude/task-context.md` if present. Present a brief summary.
2. **Enter plan mode** and stay there until the user provides a task and approves a plan. If the first message IS a task, load context silently and present the plan for it.

# User Preferences

## Scope Rules
- ONLY look at tools, repos, files, and resources the user specifically points to. Do NOT explore adjacent codebases uninvited.
- Ask more questions. Fill in all gaps. Make no dangerous assumptions. This is a real checkpoint, not a platitude — `/clarify` runs at the start of every planning phase, a gap found mid-execution stops the work and asks, and anything assumed without asking goes in the charter's `## Assumptions` register. See `~/.claude/rules/workflow.md` (Clarify First).
- Stay focused on the exact question asked.

## Connected Tools (Linear, Slack, Figma, Gmail, Calendar, Drive)
These are connected as **claude.ai account connectors** and they work. Assume they are present.
- Their tools load under **opaque UUID server ids** — `mcp__<uuid>__save_issue`, not `mcp__linear__save_issue`. The vendor name appears NOWHERE in the tool name, so `ToolSearch "linear"` returning nothing means nothing.
- The session-start banner listing `plugin:linear:linear` (or `plugin:slack:slack`) as "requires authentication" is a **different server** from the account connector. It is never grounds for saying a connector is unavailable.
- Locate tools by exact name or capability: `ToolSearch "select:save_issue,list_teams,list_issues"`, plus a scan of the deferred-tool list for `mcp__<uuid>__*` suffixes. That list fills in **incrementally** — re-run the check before acting on any earlier miss.
- **Never** tell the user a connector is unreachable, ask them to re-authorize, ask them to paste a token, or go hunting for an API key. If an exact-name `select:` search truly comes up empty this turn, say so once in a sentence naming the query, then continue with other evidence. Do not relitigate when the user says it is connected — they can see the settings pane and you cannot.

# Quick Reference (Boris v3)

```bash
# Orchestration
/boris <task>        # Plan (plan mode) -> delegate -> verify -> ship; fan-out via boris-build Workflow. DEFAULT for non-trivial tasks (auto-invoked)
/clarify             # Question checkpoint — auto-runs at the START of every planning phase, and on any gap found mid-execution
/anythingelse        # Wildcard checkpoint — auto-runs at the end of every planning phase
/loops               # One board of everything open: ledger, delegated tasks/forks, PRs, worktrees, gates
/forge               # Shared team context (optional) — teammate wip/contracts, publish yours
/session-start       # Load Memory Bank, orient to project
/session-end         # Save context for next session

# Verification & Quality
/checks              # Stack-detected gates (tests/types/lint/format/build) + Stop-hook verify gate
/verify              # Native: run the app, observe behavior
/code-review <level> # Native: review the diff (--comment, --fix; "ultra" for cloud review)
/plan-review         # Foreign-model review of the plan inside plan mode; auto-offered above the complexity bar
/cross-review [code|design|pr] # Adversarial review by a different model family; "design" catches AI-design tells, "pr" fans out to routed backends (Codex + Kimi)
/security-review     # Native: security review of the branch
/simplify            # Native: simplification pass on changed code

# Git
/task-branch <name>  # Feature branch + committed task context
/task-done           # Verify, PR, task-context cleanup
/commit-push-pr      # Full git workflow with PR
/quick-commit        # Fast local commit
/rewind              # Native: restore Claude's edits (Esc-Esc). Bad COMMIT: git reset --soft HEAD^

# Context & Memory
/memory-init         # Initialize Memory Bank for a project
/handoff             # Cognitive briefing (mental model, failed approaches, resume prompt)
/drift-check         # Validate Memory Bank against the codebase

# Issues & Learning
/fix-issue <id>      # End-to-end issue resolution
/ci-loop             # Push, watch CI in the background (non-blocking), fix, repeat
/update-claude-md    # Capture lessons from recent work
/bspec-doc           # Author a spec/PRD/architecture/decision doc in BSpec format, then validate offline
/first-principles    # Break down complex problems
```

Modes are native and harness-enforced: plan mode (Shift+Tab or `/plan`) for read-only design/review; default/acceptEdits for implementation; the audit hooks log every command and file-write to `.claude/audit/`.

# Rules

Always-on rules live in `~/.claude/rules/` (installed from this repo's `rules/`):
- `git-safety.md` — branch strategy, push-target verification, signed commits, PR review policy, recovery routing
- `workflow.md` — plan-first, delegation, verify-before-done, self-improvement loop, compaction recovery
- `documentation-channels.md` — one documentation contract for every task: Linear tracking (find/create → In Progress → comment → Done), BSpec for all saved specs/decisions, Forge for shared team context (optional; published continuously as work happens), explicit handoffs; enforced via the task-context Loops ledger
- `learned-patterns.md` — accumulated cross-project lessons. This is the lesson-capture target and the `sync-lessons.sh` sync point (public-repo promotion is opt-in via `<!-- shareable -->`)

# Memory Bank (Persistent Context)

The Memory Bank holds only **structured, human-authored** knowledge that native auto-memory doesn't provide. Per-project at `.claude/memory/`: `projectContext.md` (project identity), `decisionLog.md` (ADRs), `conventions.md` (project-specific lessons).

- **Session continuity** ("where was I", recent work) is native auto-memory (`MEMORY.md` + topic files, loaded every session) + session resume — no activeContext/progress/sessionHistory/ROUTER files.
- `.claude/task-context.md` (committed, branch-scoped) is the cross-machine handoff — `git pull` the branch on any machine and resume with full task state.
- Specialist agents (test-writer, doc-generator, code-architect, oncall-guide) carry their own `memory: project` — they learn this repo's patterns over time.
- `scripts/drift-check.sh` lints the Memory Bank (and CLAUDE.md, `.claude/rules/`) against reality (zero AI tokens); `/session-start` warns below score 80, and a post-commit hook alerts on regressions.
- Setup: `/memory-init`. Boot: `/session-start` (or the automatic SessionStart hook). Save: `/session-end` (persists new decisions/conventions, updates task-context, runs drift check).

# Core Principles

- **Simplicity First:** every change as simple as possible; minimal code impact.
- **No Laziness:** find root causes; no temporary fixes; senior developer standards.
- **Minimal Impact:** touch only what's necessary.
