# Claude Workflow

A shared Claude Code configuration that makes every team member's AI sessions smarter, safer, and continuous. Based on [claude-boris v2.0](https://github.com/llcoolblaze/claude-boris), customized with Linear integration, 120+ specialist agents, and cross-machine knowledge syncing.

## Why Use This

Without this workflow, every Claude Code session starts from zero. Claude doesn't remember what you worked on yesterday, doesn't know the mistakes it already made, and has no guardrails when it runs destructive commands. You spend the first 10 minutes of every session re-explaining context. Multiply that across a team and the waste compounds.

This workflow fixes that:

- **No more session amnesia.** The Memory Bank gives Claude persistent context per project. It remembers what was decided, what failed, and what's next. `/session-start` picks up exactly where you left off.

- **Mistakes happen once, not twice.** When Claude makes a mistake and you correct it, the lesson gets saved to Learned Patterns. Those patterns sync across machines via git, so the entire team benefits from every correction. Claude gets better the more you use it.

- **Safety rails for destructive operations.** Hooks automatically create checkpoints before `git reset --hard`, `rm -rf`, or force-pushes. Branch switches get audit-logged. You can always `/undo` or `/rollback`.

- **Complex tasks run themselves.** Instead of manually prompting Claude through multi-step work, `/boris implement user auth` plans the approach, delegates to specialist agents (architect, test-writer, security-auditor), verifies the result, and ships it. 120+ agents cover engineering, design, sales, marketing, product, QA, and more.

- **Context travels with branches.** Each feature branch carries a `.claude/task-context.md` with the objective, plan, decisions, and progress. Switch machines, switch people, `git pull` the branch and Claude has full context.

## What You Get

| Category | Count | Highlights |
|---|---|---|
| Core agents | 16 | Boris orchestrator, code-architect, test-writer, verify-app, security-auditor, linear-project-manager |
| Community agents | 105 | Engineering, design, sales, marketing, product, PM, QA, support, game dev, paid media, specialized |
| Slash commands | 23 | `/boris`, `/session-start`, `/verify-all`, `/fix-issue`, `/task-branch`, `/undo`, and more |
| Hook scripts | 3 | Session auto-loader, destructive ops guard, branch switch logger |
| Skills | 1 | Boris workflow methodology |
| Settings | -- | Wildcard permissions, Prettier hook, audit logging, deny list for dangerous ops |

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/claude-workflow.git ~/Documents/claude-workflow
cd ~/Documents/claude-workflow
chmod +x install.sh sync-lessons.sh uninstall.sh
./install.sh
```

The installer backs up your existing `~/.claude/` config, copies agents/commands/skills/hooks, merges settings (preserving your machine-specific paths and MCP permissions), and syncs Learned Patterns.

Then in any Claude Code session:

```
/session-start          # Orient Claude to your project
/memory-init            # First time in a project? Set up Memory Bank
/boris <describe task>  # Hand off a complex task to the orchestrator
```

## Daily Workflow

| Situation | Command |
|---|---|
| Start of day | `/session-start` (auto-loads context) |
| New task | `/task-branch feature/auth` then start building |
| Complex task | `/boris implement user authentication` |
| Bug from Linear | `/fix-issue PROJ-123` |
| Before merging | `/verify-all` then `/review-changes` then `/commit-push-pr` |
| Something broke | `/mode debug` then investigate then `/mode code` then fix |
| Task complete | `/task-done` (verify, PR, cleanup) |
| Context getting full | `/handoff` (auto-suggested at 60%, auto-runs at 75%) |
| End of day | `/session-end` |
| Oops | `/undo` or `/rollback` |

## Key Concepts

### Memory Bank
Each project gets a `.claude/memory/` directory with persistent files: project context, active session state, progress tracking, decision log, conventions, and session history. Claude reads these at session start and writes them at session end. The result is continuity across sessions without you re-explaining anything.

### Learned Patterns
When you correct Claude ("don't mock the database in tests", "always check column names before writing queries"), the correction gets saved as a Learned Pattern. Project-specific patterns stay in `.claude/memory/conventions.md`. Universal patterns promote to `CLAUDE.md` and sync across machines via `sync-lessons.sh` + git. Over time, Claude stops making the mistakes your team has already caught.

### Task Context
Feature branches carry `.claude/task-context.md` with the objective, plan, key decisions, and current progress. Created by `/task-branch`, auto-loaded by `/session-start`, removed when the branch merges. This means anyone (or any machine) can pick up a branch cold and Claude has full context.

### Modes
`/mode architect` (read-only design), `/mode code` (full implementation), `/mode debug` (investigation), `/mode review` (read-only code review), `/mode audit` (security scanning). Each mode restricts tool access to prevent accidents.

---

## Reference

> Full reference with all details: **[CHEATSHEET.md](CHEATSHEET.md)**

### Slash Commands

| Command | What it does |
|---|---|
| `/boris <task>` | Full orchestrated workflow -- plan, delegate, verify, ship |
| `/session-start` | Load Memory Bank, check project status, orient to continue |
| `/session-end` | Save Memory Bank state, create session summary for next time |
| `/verify-all` | Run tests, types, lint, build -- full verification suite |
| `/test-and-fix` | Run tests, analyze failures, fix, repeat until green |
| `/security-scan` | SAST, dependency CVEs, secrets detection, OWASP checks |
| `/task-branch <name>` | Create feature branch with task context for cross-machine handoff |
| `/task-done` | Complete task: verify, create PR, clean up task-context.md |
| `/commit-push-pr` | Stage, commit, push, create PR -- full git workflow |
| `/quick-commit` | Fast local commit with auto-generated message (no push) |
| `/undo` | Revert the last Claude-made change safely |
| `/checkpoint <name>` | Create a named save point for easy rollback |
| `/rollback` | Restore a previous checkpoint or go back N commits |
| `/mode <mode>` | Switch mode: `architect`, `code`, `debug`, `review`, `audit` |
| `/fix-issue <id>` | Fetch issue from Linear/GitHub, implement fix, create PR |
| `/ci-loop` | Push, wait for CI, parse failures, fix, repeat |
| `/context` | Show context window usage and Memory Bank status |
| `/memory-init` | Initialize Memory Bank for a new project |
| `/handoff` | Cognitive briefing -- saves mental model, failed approaches, resume prompt |
| `/update-claude-md` | Capture learnings into CLAUDE.md from recent work |
| `/first-principles` | Break down a complex problem from fundamentals |
| `/review-changes` | Review uncommitted changes before committing |
| `/anythingelse` | Creative wildcard prompt |

### Core Agents (16)

| Agent | Role |
|---|---|
| **boris** | Master orchestrator -- plans, delegates to specialists, verifies |
| **code-architect** | System design, architecture decisions, technical planning |
| **code-simplifier** | Clean up code after implementation -- reduce complexity |
| **test-writer** | Generate comprehensive tests (JS/TS/Python) |
| **verify-app** | End-to-end verification before shipping |
| **pr-reviewer** | Automated code review -- bugs, security, style |
| **doc-generator** | Generate/update README, API docs, CLAUDE.md |
| **ci-integrator** | CI pipeline automation -- push, monitor, fix, iterate |
| **issue-tracker** | Linear/GitHub issue management and lifecycle |
| **git-guardian** | Safe git ops -- dirty file protection, checkpoints, attribution |
| **memory-bank** | Cross-session context persistence |
| **mode-controller** | Behavioral mode switching with tool access restrictions |
| **security-auditor** | Vulnerability scanning and security assessment |
| **audit-logger** | Compliance audit trails (SOC 2, ISO 27001, HIPAA) |
| **oncall-guide** | Production incident debugging and rapid resolution |
| **linear-project-manager** | Linear-native issue, sprint, and project management |

### Community Agents (105)

Sourced from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents), covering 11 domains:

| Category | Count | Examples |
|---|---|---|
| Engineering | 22 | database-optimizer, frontend-developer, devops-automator, rapid-prototyper, SRE |
| Design | 8 | UI designer, UX architect, brand guardian, visual storyteller |
| Sales | 8 | account strategist, deal strategist, sales engineer, pipeline analyst |
| Marketing | 14 | SEO specialist, content creator, LinkedIn/Reddit/Twitter, growth hacker |
| Product | 5 | product manager, sprint prioritizer, feedback synthesizer |
| Project Management | 5 | project shepherd, experiment tracker, studio producer |
| Testing & QA | 8 | API tester, performance benchmarker, accessibility auditor |
| Support | 6 | analytics reporter, finance tracker, legal compliance |
| Game Development | 8 | game designer, narrative designer, Godot specialists |
| Paid Media | 7 | PPC strategist, programmatic buyer, creative strategist |
| Specialized | 15 | MCP builder, workflow architect, developer advocate |

Manage community agents: edit `agents/community/MANIFEST.txt` and run `scripts/sync-agency-agents.sh` to sync from upstream.

### Hooks (Automatic)

| Hook | Trigger | What it does |
|---|---|---|
| **SessionStart loader** | Every new session | Auto-loads project name, branch, last session state |
| **Destructive ops guard** | Before `git reset --hard`, `rm -rf`, force-push | Creates checkpoint tag + stashes dirty tree |
| **Branch switch logger** | After `git switch`, `git checkout <branch>` | Audit-logs branch transitions |

The SessionStart hook also detects new projects (no `.claude/project-config.json`) and prompts you to run `/memory-init`. Non-git projects can set `"git_enabled": false` in `.claude/project-config.json`.

## Customization

- **Add core agents**: Create `.md` files in `agents/` with frontmatter (`name`, `description`, `tools`)
- **Add/remove community agents**: Edit `agents/community/MANIFEST.txt` and run `scripts/sync-agency-agents.sh`
- **Add commands**: Create `.md` files in `commands/` with frontmatter (`description`)
- **Machine-specific settings**: Edit `~/.claude/settings.json` directly for paths, plugins, MCP permissions. These are preserved across `install.sh` runs.
- **New lessons**: Just work with Claude -- lessons are added to `~/.claude/CLAUDE.md` during sessions, then synced to repo via `sync-lessons.sh`

## Sync Lessons Across Machines

Learned Patterns are universal lessons that accumulate as Claude makes mistakes and you correct them. They persist across all projects.

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

How it works: bidirectional merge by `### Heading` deduplication. New local lessons go to repo, new repo lessons go to local. Never overwrites or removes existing lessons.

## Update

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
