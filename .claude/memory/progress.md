# Progress

## Completed
- [x] Boris v2.0 full workflow (15 agents, 23 commands)
- [x] Memory Bank system
- [x] Mode system (architect, code, debug, review, audit)
- [x] Feature-branch-by-default (/task-branch, /task-done)
- [x] Cognitive handoff (/handoff)
- [x] Context Guardian (auto-suggest at 60%, auto-run at 75%)
- [x] Clean all slash command inline bash (no pipes/redirects)
- [x] Fix non-git directory handling in session commands
- [x] Fix duplicated Learned Patterns
- [x] CHEATSHEET.md quick reference
- [x] README.md documentation
- [x] install.sh deployment script
- [x] sync-lessons.sh lesson promotion
- [x] GitHub repo synced (moverisJustin/claude-workflow)
- [x] Claude Code hooks: SessionStart auto-context loader
- [x] Claude Code hooks: destructive ops guard (auto-checkpoint)
- [x] Claude Code hooks: branch switch audit logger
- [x] project-config.json support for non-git projects
- [x] Hook installation in install.sh (Phase 6)
- [x] Integrate 105 community agents from agency-agents repo
- [x] Create sync-agency-agents.sh for selective upstream sync
- [x] Create MANIFEST.txt agent selection list
- [x] Create linear-project-manager agent (Linear MCP integration)
- [x] Enhance doc-generator (Divio system, docs-as-code)
- [x] Enhance oncall-guide (SLO/SLI framework, post-mortem templates)
- [x] Enhance verify-app (performance verification, Core Web Vitals)
- [x] Update boris.md with community agent delegation table
- [x] Fix WebFetch permission syntax (bare `WebFetch`, not `WebFetch(*)`)
- [x] Update install.sh for core + community agent deployment
- [x] Update README.md and CHEATSHEET.md with community agents

## Open
- [ ] Push feature/agency-agents-integration branch and create PR (or merge to main)
- [ ] End-to-end test: full /task-branch -> work -> /task-done -> PR cycle
- [ ] End-to-end test: fresh install on another machine
- [ ] Consider: hook for auto-running /session-end at context 75%
