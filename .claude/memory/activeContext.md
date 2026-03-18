# Active Context

## Current State
All planned features complete and pushed to GitHub (2026-03-17).

## Recent Work
- Added Claude Code hooks system (3 hook scripts in scripts/)
- SessionStart hook: auto-loads compact project context (~200 chars) on every new session
- Destructive ops guard: auto-checkpoints before git reset --hard, rm -rf, force-push
- Branch switch logger: audit-logs branch transitions
- Added project-config.json support to memory-init for non-git projects
- Updated settings.base.json with hook wiring (SessionStart, PreToolUse, PostToolUse)
- Updated install.sh with Phase 6 for script installation
- Updated README.md and CHEATSHEET.md with hooks documentation
- Fixed Memory Bank file names in CHEATSHEET.md (was referencing old names)

## Resume Prompt
Claude-workflow repo now has a complete hooks system. Three shell scripts in scripts/ handle auto-context loading (SessionStart), destructive operation safety (PreToolUse checkpoint), and branch switch auditing (PostToolUse). All are wired in settings.base.json and deployed via install.sh Phase 6. The project-config.json file (created by /memory-init) lets non-git projects opt out of git guards. Everything is committed and pushed to main. Next step would be end-to-end testing of the full workflow on a fresh machine.

## Next Steps
- End-to-end test: fresh install on another machine
- Test /task-branch -> work -> /task-done -> PR cycle
- Consider: hook for auto-running /session-end at context 75%
