# Claude Workflow

Personal Claude Code workflow configuration based on [claude-boris v2.0](https://github.com/llcoolblaze/claude-boris), customized with Linear integration, Python support, and cross-machine lesson syncing.

## What's Included

- **15 specialist agents** -- boris (orchestrator), code-architect, code-simplifier, test-writer, verify-app, pr-reviewer, doc-generator, ci-integrator, issue-tracker, git-guardian, memory-bank, mode-controller, security-auditor, audit-logger, oncall-guide
- **23 slash commands** -- `/boris`, `/session-start`, `/session-end`, `/verify-all`, `/test-and-fix`, `/security-scan`, `/commit-push-pr`, `/quick-commit`, `/undo`, `/checkpoint`, `/rollback`, `/mode`, `/fix-issue`, `/ci-loop`, `/context`, `/memory-init`, `/handoff`, `/update-claude-md`, `/first-principles`, `/review-changes`, `/task-branch`, `/task-done`, `/anythingelse`
- **1 skill** -- boris-workflow methodology
- **3 hook scripts** -- SessionStart context auto-loader, destructive ops guard (auto-checkpoint), branch switch audit logger
- **Settings** -- wildcard permissions, Prettier hook (JS/TS only), audit logging, deny list for dangerous ops, hook wiring
- **CLAUDE.md** -- global instructions with quick reference, workflow rules, and synced Learned Patterns

## Install

```bash
git clone https://github.com/YOUR_USERNAME/claude-workflow.git ~/Documents/claude-workflow
cd ~/Documents/claude-workflow
chmod +x install.sh sync-lessons.sh uninstall.sh
./install.sh
```

The installer:
- Backs up your existing `~/.claude/` config
- Copies agents, commands, skills, and hook scripts
- Merges settings (preserves your machine-specific paths, plugins, and MCP permissions)
- Syncs Learned Patterns between repo and local

## Usage

Start every Claude Code session with `/session-start`. End with `/session-end`.

First time in a project? Run `/memory-init` to set up the Memory Bank.

For complex tasks: `/boris <describe the task>`

## Sync Lessons Across Machines

Learned Patterns are universal lessons that accumulate as Claude makes mistakes and you correct them. They persist across all projects.

### Workflow

**After a work session (any machine):**
```bash
cd ~/Documents/claude-workflow
./sync-lessons.sh
git add CLAUDE.md && git commit -m "sync lessons" && git push
```

**On another machine:**
```bash
cd ~/Documents/claude-workflow
git pull
./sync-lessons.sh
```

### How it works

- Bidirectional merge: new local lessons go to repo, new repo lessons go to local
- Deduplication by `### Heading` -- same lesson title is never duplicated
- Never overwrites or removes existing lessons
- Only appends net-new entries

## Update

To pull the latest agents/commands/settings:

```bash
cd ~/Documents/claude-workflow
git pull
./install.sh
```

## Uninstall

```bash
cd ~/Documents/claude-workflow
./uninstall.sh
```

Restores from the most recent backup created by `install.sh`.

## Quick Reference

> Full reference with agents, modes, and workflows: **[CHEATSHEET.md](CHEATSHEET.md)**

### Slash Commands

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

### Specialist Agents

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

### Modes (`/mode <name>`)

| Mode | Focus |
|---|---|
| `architect` | Design and planning only — no code edits |
| `code` | Implementation — full tool access |
| `debug` | Diagnosis — read-heavy, minimal edits |
| `review` | Code review — read-only with comments |
| `audit` | Compliance and security review |

### Hooks (Automatic)

These run automatically via Claude Code's hook system -- no user action needed.

| Hook | Trigger | What it does | Context impact |
|---|---|---|---|
| **SessionStart loader** | Every new session | Auto-loads project name, branch, last session state | ~200 chars |
| **Destructive ops guard** | Before `git reset --hard`, `rm -rf`, force-push, etc. | Creates checkpoint tag + stashes dirty tree | Zero |
| **Branch switch logger** | After `git switch`, `git checkout <branch>` | Audit-logs branch transitions | Zero |

The SessionStart hook also detects new projects (no `.claude/project-config.json`) and prompts you to run `/memory-init`.

Non-git projects can set `"git_enabled": false` in `.claude/project-config.json` to disable git guards.

### Quick Workflows

- **Start of day:** `/session-start` (runs automatically)
- **New task:** `/task-branch feature/auth` then start building
- **Complex task:** `/boris implement user authentication`
- **Bug from Linear:** `/fix-issue MOV-123`
- **Before merging:** `/verify-all` → `/review-changes` → `/commit-push-pr`
- **Something broke:** `/mode debug` → investigate → `/mode code` → fix
- **Task complete:** `/task-done` (verify, PR, cleanup)
- **Context getting full:** `/handoff` (auto-suggested at 60%, auto-runs at 75%)
- **End of day:** `/session-end`
- **Oops:** `/undo` or `/rollback`

## Customization

- **Add agents**: Create `.md` files in `agents/` with frontmatter (`name`, `description`, `tools`)
- **Add commands**: Create `.md` files in `commands/` with frontmatter (`description`)
- **Machine-specific settings**: Edit `~/.claude/settings.json` directly for paths, plugins, MCP permissions. These are preserved across `install.sh` runs.
- **New lessons**: Just work with Claude -- lessons are added to `~/.claude/CLAUDE.md` during sessions, then synced to repo via `sync-lessons.sh`
