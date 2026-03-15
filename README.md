# Claude Workflow

Personal Claude Code workflow configuration based on [claude-boris v2.0](https://github.com/llcoolblaze/claude-boris), customized with Linear integration, Python support, and cross-machine lesson syncing.

## What's Included

- **15 specialist agents** -- boris (orchestrator), code-architect, code-simplifier, test-writer, verify-app, pr-reviewer, doc-generator, ci-integrator, issue-tracker, git-guardian, memory-bank, mode-controller, security-auditor, audit-logger, oncall-guide
- **20 slash commands** -- `/boris`, `/session-start`, `/session-end`, `/verify-all`, `/test-and-fix`, `/security-scan`, `/commit-push-pr`, `/quick-commit`, `/undo`, `/checkpoint`, `/rollback`, `/mode`, `/fix-issue`, `/ci-loop`, `/context`, `/memory-init`, `/update-claude-md`, `/first-principles`, `/review-changes`, `/anythingelse`
- **1 skill** -- boris-workflow methodology
- **Settings** -- wildcard permissions, Prettier hook (JS/TS only), audit logging, deny list for dangerous ops
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
- Copies agents, commands, and skills
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

## Key Commands Reference

| Command | What it does |
|---------|-------------|
| `/boris <task>` | Full orchestrated workflow with planning |
| `/session-start` | Load Memory Bank, orient to project |
| `/session-end` | Save context for next session |
| `/verify-all` | Run tests, types, lint, build |
| `/test-and-fix` | Fix failing tests iteratively |
| `/commit-push-pr` | Full git workflow with PR |
| `/quick-commit` | Fast local commit |
| `/undo` | Revert last Claude change |
| `/checkpoint` | Create named save point |
| `/rollback` | Restore checkpoint |
| `/fix-issue <num>` | End-to-end issue resolution |
| `/ci-loop` | Push, wait for CI, fix, repeat |
| `/security-scan` | Vulnerability checks |
| `/mode <mode>` | Switch modes (architect/code/debug/review/audit) |
| `/memory-init` | Initialize Memory Bank for project |
| `/first-principles` | Break down complex problems |

## Customization

- **Add agents**: Create `.md` files in `agents/` with frontmatter (`name`, `description`, `tools`)
- **Add commands**: Create `.md` files in `commands/` with frontmatter (`description`)
- **Machine-specific settings**: Edit `~/.claude/settings.json` directly for paths, plugins, MCP permissions. These are preserved across `install.sh` runs.
- **New lessons**: Just work with Claude -- lessons are added to `~/.claude/CLAUDE.md` during sessions, then synced to repo via `sync-lessons.sh`
