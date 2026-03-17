# Conventions & Lessons

## Slash Command Rules
- `!` backtick commands must be bare — no `2>/dev/null`, `| head`, `|| true`, pipes, or redirects
- Git commands that might run in non-git directories should be prose instructions, not `!` backtick auto-execute
- Claude Code sandbox flags "multiple operations" for any inline bash with pipes or redirects

## Deployment
- Always run `install.sh` after modifying commands/agents/CLAUDE.md to deploy to ~/.claude/
- Always push to GitHub after deploying so remote stays in sync
- Verify push target with `git remote -v` before pushing

## CLAUDE.md Sync
- `sync-lessons.sh` handles copying learned patterns from repo CLAUDE.md to ~/.claude/CLAUDE.md
- Watch for duplicate patterns — the script appends without checking for existing entries
- After manual edits to CLAUDE.md, verify no duplicates before committing
