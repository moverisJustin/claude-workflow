# Boris v2.0 Cheat Sheet

Quick reference for all slash commands, specialist agents, and modes.

## Slash Commands

| Command | What it does |
|---|---|
| `/boris <task>` | Full orchestrated workflow — plan, delegate, verify, ship |
| `/session-start` | Load Memory Bank, check project status, orient to continue |
| `/session-end` | Save Memory Bank state, create session summary for next time |
| `/verify-all` | Run tests, types, lint, build — full verification suite |
| `/test-and-fix` | Run tests, analyze failures, fix, repeat until green |
| `/security-scan` | SAST, dependency CVEs, secrets detection, OWASP checks |
| `/task-branch <name>` | Create feature branch with task context for cross-machine handoff |
| `/task-done` | Complete task: verify, create PR, clean up task-context.md |
| `/commit-push-pr` | Stage, commit, push, create PR — full git workflow |
| `/quick-commit` | Fast local commit with auto-generated message (no push) |
| `/undo` | Revert the last Claude-made change safely |
| `/checkpoint <name>` | Create a named save point for easy rollback |
| `/rollback` | Restore a previous checkpoint or go back N commits |
| `/mode <mode>` | Switch mode: `architect`, `code`, `debug`, `review`, `audit` |
| `/fix-issue <id>` | Fetch issue from Linear/GitHub, implement fix, create PR |
| `/ci-loop` | Push, wait for CI, parse failures, fix, repeat |
| `/context` | Show context window usage and Memory Bank status |
| `/memory-init` | Initialize Memory Bank for a new project |
| `/handoff` | Cognitive briefing — saves mental model, failed approaches, resume prompt |
| `/update-claude-md` | Capture learnings into CLAUDE.md from recent work |
| `/first-principles` | Break down a complex problem from fundamentals |
| `/review-changes` | Review uncommitted changes before committing |
| `/anythingelse` | Creative wildcard prompt |

## Core Agents (16)

| Agent | Role |
|---|---|
| **boris** | Master orchestrator — plans, delegates to specialists, verifies |
| **code-architect** | System design, architecture decisions, technical planning |
| **code-simplifier** | Clean up code after implementation — reduce complexity |
| **test-writer** | Generate comprehensive tests (JS/TS/Python) |
| **verify-app** | End-to-end verification + performance checks |
| **pr-reviewer** | Automated code review — bugs, security, style |
| **doc-generator** | Generate/update docs (Divio system, docs-as-code) |
| **ci-integrator** | CI pipeline automation — push, monitor, fix, iterate |
| **issue-tracker** | Linear/GitHub issue management and lifecycle |
| **git-guardian** | Safe git ops — dirty file protection, checkpoints, attribution |
| **memory-bank** | Cross-session context persistence |
| **mode-controller** | Behavioral mode switching with tool access restrictions |
| **security-auditor** | Vulnerability scanning and security assessment |
| **audit-logger** | Compliance audit trails (SOC 2, ISO 27001, HIPAA) |
| **oncall-guide** | Production incidents + SLO/SLI framework + post-mortems |
| **linear-project-manager** | Linear-native issue, sprint, and project management |

## Community Agents (105)

From [agency-agents](https://github.com/msitarzewski/agency-agents). Key ones for dev work:

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
| `product-manager` | Product strategy, prioritization |
| `marketing-content-creator` | Blog posts, marketing copy |

Full list: `ls agents/community/` or see `agents/community/MANIFEST.txt`

## Modes (`/mode <name>`)

| Mode | Focus |
|---|---|
| `architect` | Design and planning only — no code edits |
| `code` | Implementation — full tool access |
| `debug` | Diagnosis — read-heavy, minimal edits |
| `review` | Code review — read-only with comments |
| `audit` | Compliance and security review |

## Hooks (Automatic)

| Hook | Trigger | What it does | Context impact |
|---|---|---|---|
| **SessionStart loader** | Every new session | Auto-loads project name, branch, last session state | ~200 chars |
| **Destructive ops guard** | Before `git reset --hard`, `rm -rf`, force-push | Auto-checkpoint tag + stash dirty tree | Zero |
| **Branch switch logger** | After `git switch`/`git checkout <branch>` | Audit-logs branch transitions | Zero |

Non-git projects: set `"git_enabled": false` in `.claude/project-config.json`.

## Quick Workflows

**Start of day:**
`/session-start` (runs automatically on new sessions)

**New task:**
`/task-branch feature/auth` then start building

**Complex task:**
`/boris implement user authentication`

**Bug from Linear:**
`/fix-issue MOV-123`

**Before merging:**
`/verify-all` → `/review-changes` → `/commit-push-pr`

**Something broke:**
`/mode debug` → investigate → `/mode code` → fix

**Task complete:**
`/task-done` (verify, PR, cleanup)

**Context getting full:**
`/handoff` (auto-suggested at 60%, auto-runs at 75%)

**End of day:**
`/session-end`

**Oops:**
`/undo` or `/rollback`

## Memory Bank

Each project gets a `.claude/memory/` directory with persistent context:

| File | Purpose |
|---|---|
| `projectContext.md` | What the project is, tech stack, architecture |
| `activeContext.md` | Current focus, recent changes, next steps |
| `progress.md` | What works, what doesn't, what's left |
| `decisionLog.md` | Architecture decisions with rationale |
| `conventions.md` | Project-specific lessons and rules |
| `sessionHistory.md` | Rolling session summaries |

Also: `.claude/project-config.json` stores git preference and project description.

Initialize with `/memory-init`. Context auto-loads via SessionStart hook + `/session-start`.

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
2. **Universal** → `~/.claude/CLAUDE.md` Learned Patterns (applies everywhere)

Sync across machines:
```bash
cd ~/Documents/claude-workflow
./sync-lessons.sh
git add CLAUDE.md && git commit -m "sync lessons" && git push
```
