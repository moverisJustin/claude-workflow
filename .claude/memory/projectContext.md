# Project Context — Claude Workflow (Boris v2.0)

## What This Is
A portable, repo-synced configuration system for Claude Code that provides:
- **15 specialist agents** (boris, code-architect, git-guardian, verify-app, etc.)
- **23 slash commands** (/session-start, /session-end, /task-branch, /task-done, /handoff, etc.)
- **Memory Bank** for persistent cross-session context
- **Mode system** (architect, code, debug, review, audit)
- **Feature-branch-by-default** workflow with per-branch task context

## Repository
- **GitHub**: `moverisJustin/claude-workflow` (private)
- **Local**: `/Users/justinkeene/Documents/claude-workflow`
- **Deploys to**: `~/.claude/` via `install.sh`

## Key Files
- `CLAUDE.md` — Master config (copied to ~/.claude/CLAUDE.md on install)
- `commands/*.md` — Slash command definitions (23 files)
- `agents/*.md` — Specialist agent definitions (15 files)
- `skills/boris-workflow.md` — Boris skill definition
- `settings.base.json` — Base permissions template
- `install.sh` — Deploys everything to ~/.claude/
- `sync-lessons.sh` — Promotes learned patterns from project conventions to global CLAUDE.md
- `CHEATSHEET.md` — Quick reference card
- `README.md` — Full documentation

## How It Works
1. User runs `install.sh` from this repo
2. Script copies agents, commands, skills, settings to `~/.claude/`
3. Syncs learned patterns from CLAUDE.md
4. All Claude Code sessions now have access to Boris workflow

## Architecture Decisions
- Commands use `!` backtick syntax for auto-executing simple commands (no pipes, redirects, or error suppressors)
- Git commands in session-start/session-end/handoff are prose instructions (not auto-execute) to handle non-git directories gracefully
- Memory Bank is per-project (`.claude/memory/`), task context is per-branch (`.claude/task-context.md`)
- Learned patterns promote from project-level conventions.md to global CLAUDE.md
