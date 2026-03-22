# Session History

## 2026-03-19 — Agency-Agents Integration (105 Community Agents)
### What Was Accomplished
- Integrated 105 community agents from msitarzewski/agency-agents repo
- Created `scripts/sync-agency-agents.sh` for selective upstream sync via MANIFEST.txt
- Created `agents/community/MANIFEST.txt` with 105 agent slugs across 11 categories
- Created `agents/linear-project-manager.md` (custom Linear MCP agent)
- Enhanced 3 core agents: doc-generator (Divio system), oncall-guide (SLO/SLI), verify-app (Core Web Vitals)
- Updated boris.md with community agent delegation table
- Fixed WebFetch permission bug: `WebFetch(*)` is invalid, must use bare `WebFetch`
- Updated install.sh to deploy both core (16) and community (105) agents
- Updated README.md and CHEATSHEET.md with full community agents documentation

### Commits
- `2f327dc` feat: integrate 105 community agents from agency-agents + enhancements

### Key Decisions
- Two-tier agent system: core (`agents/`) vs community (`agents/community/`)
- MANIFEST.txt as single source of truth for agent selection
- Excluded: spatial computing, academic, Chinese social media, Unity/Unreal/Roblox/Blender, Jira

### Lessons Learned
- `WebFetch(*)` wildcard syntax only works for Bash rules; use bare `WebFetch` for non-Bash tools
- Agency-agents file naming is inconsistent — game-dev and specialized agents omit category prefix
- Always verify actual upstream filenames before building a manifest

### Open Items
- [ ] Push branch and create PR or merge to main
- [ ] Fresh install end-to-end test

---

## 2026-03-17 (evening) — Claude Code Hooks System
### What Was Accomplished
- Created 3 hook scripts: session-start auto-loader, destructive ops guard, branch switch logger
- Wired hooks into settings.base.json (SessionStart, PreToolUse, PostToolUse)
- Added install.sh Phase 6 for script deployment
- Added project-config.json to memory-init for non-git project support
- Updated README.md and CHEATSHEET.md with hooks documentation
- Fixed outdated Memory Bank file names in CHEATSHEET.md
- All tested locally and pushed to main

### Commits
- `0590c51` feat: add Claude Code hooks for auto-context, destructive ops guard, and branch audit

### Context
Session had multiple API 529 errors requiring restarts. Work was resilient — scripts created in earlier attempts survived across restarts. Key design decision: SessionStart hook output capped at 1500 chars to avoid context bloat.

## 2026-03-17 — Memory Bank Initialization
### What Was Accomplished
- Initialized Memory Bank for claude-workflow repo
- Fixed session-end/session-start/handoff non-git directory errors
- Fixed duplicated Learned Patterns in CLAUDE.md
- Deployed fixes and pushed to GitHub

### Context
This is the first session with Memory Bank in this repo. Previous sessions predated the Memory Bank system.
