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
- Their tools load under an **opaque UUID server id** — Linear is `mcp__1454a9ef-f670-467d-a8f8-b5992bc8dcd0__save_issue`, not `mcp__linear__save_issue`. The vendor name appears NOWHERE in the tool name, so `ToolSearch "linear"` returning nothing means nothing.
- **How to load them** (all three verified 2026-08-05):
  - `ToolSearch "+save_issue"` — the `+term` form matches on tool name and needs no UUID. Start here.
  - To batch, copy `mcp__<uuid>__*` names verbatim off the deferred-tool list in the system reminder into `select:`.
  - **`select:` with BARE names cannot match.** It compares the *full* tool name, so `select:save_issue,list_teams,list_issues` returns nothing while every tool works fine. A bare-name miss is evidence of nothing — never report one as a connector problem.
- Real Linear tool names: `save_issue` (creates AND updates), `save_comment`, `list_issues`, `list_teams`, `list_projects`, `get_issue`. There is no `create_issue`, `update_issue`, or `create_comment`.
- `permissions.allow` in `~/.claude/settings.json` is a permission list, **not** a server registry. Names appearing there (`mcp__claude_ai_Linear__*`, `mcp__plugin_linear_linear__*`) are dead. Never infer routing or availability from a config file — probe with ToolSearch.
- The session-start banner listing `plugin:linear:linear` (or `plugin:slack:slack`) as "requires authentication" is a **different server** from the account connector. It is never grounds for saying a connector is unavailable, and never a reason to skip the search.
- When a corrected query succeeds after an earlier miss, **do not say the tools "just populated."** They were listed in the first system-reminder of the session; the earlier query was malformed. Say that instead.
- **Never** tell the user a connector is unreachable, ask them to re-authorize, ask them to paste a token, or go hunting for an API key. Do not relitigate when the user says it is connected — they can see the settings pane and you cannot. If `+name` AND a UUID-prefixed `select:` both come up empty in the same turn, say so once naming both queries, then continue with other evidence; a bare-name miss never qualifies.

# Orchestration defaults

Skills self-describe — the harness already lists every skill with its description, so
this file does not restate them. What is NOT obvious from that list:

- **`/boris` is the default** for any non-trivial dev task. Auto-invoke it when the user
  starts describing work to build, fix, or change; they should never need to type it.
  Trivial fixes and pure questions skip the ceremony (say so).
- `/clarify` then `/anythingelse` run at every planning phase, in that order.
- `/loops` is the board of everything still in flight. `/session-start` and `/session-end`
  bracket the session.
- Recovery routing: `/rewind` (Esc-Esc) for Claude's edits; `git reset --soft HEAD^` for a
  bad commit; `git tag -l 'auto-checkpoint/*'` for files a bash command destroyed.

Modes are native and harness-enforced: plan mode (Shift+Tab or `/plan`) for read-only
design/review; default/acceptEdits for implementation; the audit hooks log every command
and file-write to `.claude/audit/`.

# Rules

Always-on rules live in `~/.claude/rules/` (installed from this repo's `rules/`):
- `writing.md` — the writing contract for everything a human reads: the `## Brief` block, the
  six-field decision brief, 15 rules derived from ASD-STE100 Issue 9, the do-not-use list, and
  `## The chat stream` — the rules for every answer Claude writes to you (lead with the answer,
  say where you are, no preamble or closer, and never let a coined name stand in for its
  meaning). The prose rules bind the Brief, decision asks, and turn summaries; the chat rules
  bind the running chat; neither binds the technical body. Enforced by `scripts/ste-check.sh`
  at plan approval, in `/checks`, in `/task-done`, and in CI; `ste-check.sh --chat` checks a
  pasted answer on demand.
- `git-safety.md` — branch strategy, push-target verification, signed commits, PR review policy, recovery routing
- `workflow.md` — plan-first, delegation, verify-before-done, self-improvement loop, compaction recovery
- `documentation-channels.md` — one documentation contract for every task: Linear tracking (find/create → In Progress → comment → Done), BSpec for all saved specs/decisions, Forge for shared team context (optional; published continuously as work happens), explicit handoffs; enforced via the task-context Loops ledger
- `learned-patterns.md` — the always-on **hot core** (10 rules that apply to every session) plus a
  heading index of the deferred corpus at `~/.claude/lessons/learned-patterns.md`, which is NOT
  auto-loaded. Retrieve deferred lessons with `memory-context.sh --grep '<keyword>'`. The corpus is
  the lesson-capture and `sync-lessons.sh` target (public-repo promotion is opt-in via `<!-- shareable -->`);
  `scripts/reindex-lessons.sh` regenerates the index after an append.

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
