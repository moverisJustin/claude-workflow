# Active Context

## Current State
On branch `feature/agency-agents-integration`. Committed but not yet pushed or PR'd. All work deployed locally via install.sh (121 agents working).

## Recent Work (2026-03-19)
- Integrated 105 community agents from msitarzewski/agency-agents repo
- Created sync-agency-agents.sh for selective upstream sync via MANIFEST.txt
- Created linear-project-manager.md (custom Linear MCP agent)
- Enhanced doc-generator (docs-as-code, Divio system)
- Enhanced oncall-guide (SLO/SLI framework, post-mortem templates)
- Enhanced verify-app (performance verification: Core Web Vitals, bundle size)
- Updated boris.md with community agent delegation table
- Fixed WebFetch permission: `WebFetch(*)` is invalid, must use bare `WebFetch`
- Updated install.sh to deploy both core (16) and community (105) agents
- Updated README.md and CHEATSHEET.md

## Resume Prompt
The claude-workflow repo now has 121 agents (16 core + 105 community from agency-agents). Community agents are managed via agents/community/MANIFEST.txt and synced from upstream with scripts/sync-agency-agents.sh. A new linear-project-manager agent was created for Linear MCP integration. Three core agents were enhanced with content from the richer agency-agents (doc-generator, oncall-guide, verify-app). The WebFetch permission bug was fixed (bare tool name, no parentheses). Everything is committed on feature/agency-agents-integration but needs to be pushed and PR'd or merged to main.

## Failed Approaches
- `WebFetch(*)` pattern doesn't work -- wildcard syntax only applies to Bash rules. Must use bare `WebFetch`.
- Initial MANIFEST.txt had wrong slugs for game-dev and specialized agents (they don't use category prefix in filenames).

## Next Steps
- Push branch and create PR (or merge to main)
- End-to-end test: fresh install on another machine
- Test /task-branch -> work -> /task-done -> PR cycle
- Consider: hook for auto-running /session-end at context 75%
