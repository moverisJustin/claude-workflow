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
| `/update-claude-md` | Capture learnings into CLAUDE.md from recent work |
| `/first-principles` | Break down a complex problem from fundamentals |
| `/review-changes` | Review uncommitted changes before committing |
| `/anythingelse` | Creative wildcard prompt |

## Specialist Agents

| Agent | Role |
|---|---|
| **boris** | Master orchestrator — plans, delegates to specialists, verifies |
| **code-architect** | System design, architecture decisions, technical planning |
| **code-simplifier** | Clean up code after implementation — reduce complexity |
| **test-writer** | Generate comprehensive tests (JS/TS/Python) |
| **verify-app** | End-to-end verification before shipping |
| **pr-reviewer** | Automated code review — bugs, security, style |
| **doc-generator** | Generate/update README, API docs, CLAUDE.md |
| **ci-integrator** | CI pipeline automation — push, monitor, fix, iterate |
| **issue-tracker** | Linear/GitHub issue management and lifecycle |
| **git-guardian** | Safe git ops — dirty file protection, checkpoints, attribution |
| **memory-bank** | Cross-session context persistence |
| **mode-controller** | Behavioral mode switching with tool access restrictions |
| **security-auditor** | Vulnerability scanning and security assessment |
| **audit-logger** | Compliance audit trails (SOC 2, ISO 27001, HIPAA) |
| **oncall-guide** | Production incident debugging and rapid resolution |

## Modes (`/mode <name>`)

| Mode | Focus |
|---|---|
| `architect` | Design and planning only — no code edits |
| `code` | Implementation — full tool access |
| `debug` | Diagnosis — read-heavy, minimal edits |
| `review` | Code review — read-only with comments |
| `audit` | Compliance and security review |

## Quick Workflows

**Start of day:**
`/session-start` (runs automatically on new sessions)

**Complex task:**
`/boris implement user authentication`

**Bug from Linear:**
`/fix-issue MOV-123`

**Before merging:**
`/verify-all` → `/review-changes` → `/commit-push-pr`

**Something broke:**
`/mode debug` → investigate → `/mode code` → fix

**End of day:**
`/session-end`

**Oops:**
`/undo` or `/rollback`

## Memory Bank

Each project gets a `.claude/memory/` directory with persistent context:

| File | Purpose |
|---|---|
| `projectbrief.md` | What the project is, goals, constraints |
| `productContext.md` | Why it exists, user problems it solves |
| `systemPatterns.md` | Architecture, patterns, key decisions |
| `techContext.md` | Stack, dependencies, tooling, dev setup |
| `activeContext.md` | Current focus, recent changes, next steps |
| `progress.md` | What works, what doesn't, what's left |
| `conventions.md` | Project-specific lessons and rules |

Initialize with `/memory-init`. Context loads automatically via `/session-start`.

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
