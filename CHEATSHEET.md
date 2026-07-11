# Boris v3 Cheat Sheet

Quick reference for all skills, specialist agents, and native replacements.

## Skills (invoke as `/name`)

Every former command is a skill now (`skills/<name>/SKILL.md`) — same `/name` invocation, plus tool grants (fewer permission prompts on git skills), argument hints, and invocation control (side-effectful skills are user-invoked only; Claude can auto-load the rest when relevant).

| Skill | What it does |
|---|---|
| `/boris <task>` | Full orchestrated workflow — plan, delegate, verify, ship. **Auto-invoked by default** for non-trivial tasks |
| `/cross-review [code\|design]` | Adversarial review by OpenAI Codex (decorrelated model family); `design` mode catches AI-design tells |
| `/loops` | One board of everything open: Loops ledger, delegated tasks/forks, PRs, worktrees, stashes, gates |
| `/session-start` | Deep-orient: load Memory Bank + task-context, check status, drift/signing |
| `/session-end` | Commit/stash work, persist new decisions/conventions, update task-context |
| `/checks` | Stack-detected quality gates (tests, types, lint, format, build) + Stop-hook verify gate |
| `/task-branch <name>` | Create feature branch with task context for cross-machine handoff |
| `/task-done` | Complete task: verify, create PR, clean up task-context.md |
| `/commit-push-pr` | Stage, commit, push, create PR — full git workflow |
| `/quick-commit` | Fast local commit with auto-generated message (no push) |
| `/fix-issue <id>` | Fetch issue from Linear/GitHub, implement fix, create PR |
| `/ci-loop` | Push, watch CI in the **background** (no blocked turn), fix failures, repeat until green |
| `/memory-init` | Initialize Memory Bank for a new project |
| `/handoff` | Cognitive briefing — saves mental model, failed approaches, resume prompt |
| `/drift-check` | Validate Memory Bank accuracy against codebase — suggest and auto-fix drift |
| `/update-claude-md` | Capture learnings into CLAUDE.md from recent work |
| `/bspec-doc` | Author a spec/PRD/feature/architecture/decision doc in BSpec format, then validate it offline (`scripts/bspec-validate.sh`) |
| `/memory-migrate` | Convert a project's pre-v3 Memory Bank to v3 (auto-offered at session start when detected) |
| `/first-principles` | Break down a complex problem from fundamentals |
| `/anythingelse` | Creative wildcard prompt — auto-runs at the end of every planning phase |

## Native Replacements (retired workflow commands)

Claude Code now does these natively — harness-enforced, better than the prose versions they replace:

| Was | Now (native) |
|---|---|
| `/verify-all`, `/test-and-fix` | `/verify` (runs the app, observes behavior) + `/checks` (this repo's stack-detected gates) |
| `/review-changes` | `/code-review <effort>` — `--comment` posts inline PR comments, `--fix` applies findings, `ultra` = multi-agent cloud review |
| `/security-scan` | `/security-review` on the branch |
| `/undo`, `/checkpoint`, `/rollback` | `/rewind` (Esc-Esc) — automatic per-prompt checkpoints, survive `/clear`, 30 days. Undo a *commit*: `git reset --soft HEAD^`. Bash-destroyed files: `git tag -l 'auto-checkpoint/*'` |
| `/mode architect`, `/mode review` | Native plan mode (Shift+Tab or `/plan`) — read-only enforced by the harness |
| `/mode audit` | PreToolUse audit hooks (`.claude/audit/`, self-gitignored) + `/security-review` |
| `/context` | Native `/context` + statusline (live context %, real numbers) |

## Core Agents (8)

Boris is a **skill** now (`/boris`), not an agent — it plans in native plan mode, delegates via the Agent tool (forks, background, worktree isolation), and launches the `boris-build` saved Workflow for fan-out-scale jobs. Each core agent is pinned to a model tier (opus for judgment, sonnet for implementers, haiku for CRUD/deterministic work).

| Agent | Role |
|---|---|
| **code-architect** | System design, architecture decisions, technical planning |
| **test-writer** | Generate comprehensive tests (JS/TS/Python) |
| **doc-generator** | Generate/update docs (Divio system, docs-as-code) |
| **issue-tracker** | Linear/GitHub issue management and lifecycle |
| **git-guardian** | Git safety — push-target/staging verification, branch protection |
| **memory-bank** | Cross-session context persistence |
| **oncall-guide** | Production incidents + SLO/SLI framework + post-mortems |
| **linear-project-manager** | Linear-native issue, sprint, and project management |

Retired agents (native now): code-simplifier → `/simplify`, verify-app → `/verify` + `/checks`, pr-reviewer → `/code-review`, security-auditor → `/security-review`, mode-controller → native plan/permission modes, audit-logger → the audit hooks.

## Community Agents (44 active / 105 vendored)

From [agency-agents](https://github.com/msitarzewski/agency-agents), pinned to a reviewed commit. The dev-focused set (engineering, testing, dev design/specialized) installs by default, each with a model tier applied at deploy time (dev → sonnet, advisory → haiku + read-only tools). Sales/marketing/product/support/game/paid-media stay vendored but opt-in — uncomment in `MANIFEST.txt` and re-run `install.sh`. Key active ones:

| Agent | Use For |
|---|---|
| `engineering-database-optimizer` | Schema review, query optimization, N+1 detection |
| `engineering-frontend-developer` | React/CSS/a11y, Core Web Vitals |
| `engineering-devops-automator` | Docker, CI/CD, infrastructure-as-code |
| `testing-api-tester` | API contract testing, endpoint validation |
| `testing-performance-benchmarker` | Load testing, k6, Lighthouse |
| `testing-accessibility-auditor` | WCAG 2.2 compliance |
| `specialized-mcp-builder` | Building new MCP servers |
| `engineering-sre` | SLO definitions, error budgets, observability |
| `engineering-security-engineer` | Threat modeling, secure code review |
| `blockchain-security-auditor` | Smart-contract audit, exploit analysis |

Full list: `ls agents/community/` or see `agents/community/MANIFEST.txt`

## Modes (Native, Harness-Enforced)

| Need | Use |
|---|---|
| Design/review without edits | Plan mode (Shift+Tab or `/plan`) — read-only guaranteed by the harness |
| Implementation | Default / acceptEdits permission modes |
| Audit trail | PreToolUse hooks log commands + file-writes to `.claude/audit/` |
| Security pass | `/security-review` |

## Hooks (Automatic)

| Hook | Trigger | What it does | Context impact |
|---|---|---|---|
| **SessionStart loader** | Every new session | Auto-loads project name, branch, task-context objective, drift/signing warnings | ~200 chars |
| **Destructive ops guard** | Before `git reset --hard`, `rm -rf`, force-push | Non-mutating checkpoint (tag + stash snapshot); asks for confirmation on high-risk `rm -rf` targets | Zero |
| **Audit logger** | Before Bash / Edit / Write | Appends command + file-write trail to `.claude/audit/` | Zero |
| **Drift watcher** | After `git commit` | Runs drift check, alerts if Memory Bank score < 80 | Zero when healthy |
| **Prettier** | After Edit/Write of js/ts/css/md | Formats with the project's prettier (skips projects without it) | Zero |
| **Compaction snapshot** | Before context compaction | Writes git state to `.claude/memory/compaction-snapshot.md` (PreCompact consumes no hook output — this is a side effect) | Zero |
| **Post-compaction recovery** | After compaction (SessionStart `compact`) | Injects "verify summary against snapshot, save handoff to task-context.md" | ~300 chars, post-compaction only |
| **Verify gate** | Turn end (Stop), only while `/checks` has the gate armed | Blocks ending the turn until quality gates pass or are explicitly waived; 3-attempt escape hatch, 2h staleness disarm | Zero on normal turns |

Non-git projects: set `"git_enabled": false` in `.claude/project-config.json`.

## Quick Workflows

**Start of day:**
`/session-start` (runs automatically on new sessions)

**New task:**
`/task-branch feature/auth` then start building

**Complex task:**
`/boris implement user authentication`

**Bug from Linear:**
`/fix-issue PROJ-123`

**Before merging:**
`/checks` → `/code-review medium` → `/commit-push-pr`

**Something broke:**
Point Claude at the logs/error — it diagnoses and fixes (plan mode first if you want read-only investigation)

**Task complete:**
`/task-done` (verify, PR, cleanup)

**Context getting full:**
`/handoff` (run it before breaks; compaction is auto-covered by the PreCompact snapshot + post-compaction recovery hooks)

**End of day:**
`/session-end`

**Oops:**
`/rewind` (Esc-Esc) for Claude's edits; `git reset --soft HEAD^` for a bad commit; `git tag -l 'auto-checkpoint/*'` for bash-destroyed files

## Memory Bank

Each project's `.claude/memory/` holds three **structured, human-authored** files — the knowledge native auto-memory doesn't provide:

| File | Purpose |
|---|---|
| `projectContext.md` | What the project is, tech stack, architecture |
| `decisionLog.md` | Architecture decisions with rationale (ADRs) |
| `conventions.md` | Project-specific conventions and lessons |

Session continuity ("where was I", recent work, summaries) is **native auto-memory** (`MEMORY.md` + topic files, loaded every session) + session resume — no activeContext/progress/sessionHistory/ROUTER files. Also: `.claude/project-config.json` stores git preference and project description.

Initialize with `/memory-init`. Orient via the SessionStart hook + `/session-start`.

### Agent Memory

The recurring specialist agents (test-writer, doc-generator, code-architect, oncall-guide) carry `memory: project` — they learn this repo's patterns across sessions instead of rediscovering them each run.

### Drift Detection

`/drift-check` validates that the Memory Bank, `CLAUDE.md`, and `.claude/rules/` still match codebase reality (dead paths, stale branches, missing deps). Pure bash, zero AI tokens. Integrated into `/session-start` (warns if score < 80) and `/session-end` (catches self-introduced drift).

## Task Context (Branch-Specific)

Each feature branch can carry its own task context in `.claude/task-context.md`:

| Field | Purpose |
|---|---|
| Branch | Name, creation date, base commit |
| Objective | What this branch exists to accomplish |
| Plan | Checklist of steps |
| Decisions | Key decisions with rationale |
| Progress | Done / In Progress / Blocked |
| Notes | Context for someone picking this up cold |

- Created by `/task-branch` or `/fix-issue`
- Auto-loaded by `/session-start`, auto-saved by `/session-end`
- Committed to git for cross-machine handoff (`git pull` on the branch)
- Removed when branch merges to main (via `/task-done`)

## Lesson Syncing

Lessons promote upward:
1. **Project-specific** → `.claude/memory/conventions.md` (stays in project)
2. **Universal** → `~/.claude/rules/learned-patterns.md` (applies everywhere, stays local by default)

Sharing to the **public** repo is **opt-in**: `sync-lessons.sh` promotes a lesson only if its
block carries a `<!-- shareable -->` marker (on the line under its `### ` heading). Untagged
lessons stay local so private/org-specific notes never leak. Repo → local is unchanged.

Sync across machines:
```bash
cd ~/Documents/claude-workflow
./sync-lessons.sh   # only <!-- shareable --> lessons promote; rest kept local
git add rules/learned-patterns.md && git commit -m "sync lessons" && git push
```
Privacy guard test: `./test-sync-lessons.sh`
