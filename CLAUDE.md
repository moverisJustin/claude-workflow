# Session Boot (MANDATORY)

**Every session MUST begin with these two actions before doing anything else:**

1. **Load context**: Execute the `/session-start` protocol — read `.claude/memory/activeContext.md`, `progress.md`, `conventions.md`, `projectContext.md` (or fall back to `tasks/handoff.md`, `tasks/todo.md`, `tasks/lessons.md`). Check `git status`, `git branch`, and recent commits. Synthesize and present a brief summary to the user.

2. **Enter plan mode**: After presenting the session summary, enter plan mode. Stay in plan mode until the user provides a task and approves a plan. Do NOT begin implementation without an approved plan.

This applies to every new session — CLI, desktop app, and IDE. No exceptions. If the user's first message is a task, load context silently and present the plan for that task (combining steps 1 and 2). If the user's first message is a greeting or question, load context first and then respond.

---

# User Preferences

## Scope Rules
- ONLY look at tools, repositories, files, and resources that the user specifically links or points to. Do NOT explore adjacent repos, plugins, or codebases on your own initiative.
- Do not assume what the user wants — ask if unclear rather than guessing and going off on tangents.
- Stay focused on the exact question asked. Do not expand scope beyond what was requested.

---

# Quick Reference (Boris v2.0)

```bash
# Boris Workflow
/boris <task>        # Full orchestrated workflow with planning
/session-start       # Load Memory Bank, orient to project
/session-end         # Save context for next session

# Verification & Quality
/verify-all          # Run tests, types, lint, build
/test-and-fix        # Fix failing tests iteratively
/security-scan       # Check for vulnerabilities
/review-changes      # Pre-commit code review

# Git Workflow
/task-branch <name>  # Create feature branch + task context
/task-done           # Complete task: verify, PR, cleanup
/commit-push-pr      # Full git workflow with PR
/quick-commit        # Fast local commit
/undo                # Revert last Claude change
/checkpoint [name]   # Create named save point
/rollback [target]   # Restore checkpoint

# Context & Memory
/context             # Check context usage
/memory-init         # Initialize Memory Bank for project
/handoff             # Cognitive briefing for seamless session handoff

# Mode System
/mode [mode]         # Switch modes (architect/code/debug/review/audit)

# Issue Tracking
/fix-issue <num>     # End-to-end issue resolution
/ci-loop             # Push, wait for CI, fix, repeat

# Learning
/update-claude-md    # Learn from mistakes
/first-principles    # Break down complex problems
```

---

# Workflow Orchestration (Boris v2.0)

## 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

## 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution
- Use specialist agents: code-architect, code-simplifier, test-writer, verify-app, pr-reviewer, doc-generator, oncall-guide
- Match agent to task type (see agents in ~/.claude/agents/)

## 3. Self-Improvement Loop
- After ANY correction from the user: update `.claude/memory/conventions.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review conventions at session start for relevant project
- **Lesson promotion:** When writing to `.claude/memory/conventions.md`, evaluate if the lesson is project-specific or universal
  - **Universal lessons** (workflow patterns, common pitfalls, user preferences, cross-project mistakes) → also add to the "Learned Patterns" section in `~/.claude/CLAUDE.md`
  - **Project-specific lessons** (repo quirks, specific APIs, local tooling) → stay in `.claude/memory/conventions.md` only

## 4. Verification Before Done
- Never mark a task complete without proving it works
- Use `/verify-all` command for automated checks (tests, types, lint, build)
- Invoke verify-app agent for comprehensive testing
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

## 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

## 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## 7. Git Safety
- Use `/checkpoint` before risky changes
- Use `/undo` to revert Claude-made commits
- Use `/rollback` to restore checkpoints
- Auto-stash dirty files before AI modifications
- Never force-push to main/master
- Always verify push target with `git remote -v` before pushing

## 8. Branch Strategy (Feature-Branch-by-Default)
- ALL work happens on feature branches, NOT main
- Exception: initial build phase of a new project (< 5 commits) may use main
- Every feature branch gets `.claude/task-context.md` (committed, not gitignored)
- `/task-branch <name>` to start, `/task-done` to finish
- Cross-machine handoff: just `git pull` on the branch
- When branch merges to main, task-context.md is removed
- `/fix-issue` auto-creates task context from issue details
- Branch naming: `feature/`, `fix/`, `task/` prefixes

## 9. Context Guardian (Proactive Rescue)
- **At ~60% context usage**: Proactively tell the user: "Context is getting full. Want me to run `/handoff` to save cognitive state?"
- **At ~75% context usage**: Auto-run `/handoff` without asking. Save the cognitive briefing to activeContext.md and task-context.md. Then tell the user context is preserved.
- **Before any `/session-end`**: Generate the cognitive briefing (resume prompt, mental model, failed approaches, active hypotheses) as part of the session-end flow
- **Priority**: If context is critically low, saving the handoff briefing is MORE important than finishing the current subtask. A lost mental model costs more than a half-finished function.
- The cognitive briefing captures THINKING (why, how, what failed) not just DOING (which files changed)
- `/handoff` can be run manually at any time for an immediate cognitive snapshot

## 10. Mode System
- `/mode architect` — read-only design mode (no file edits)
- `/mode code` — full development (default)
- `/mode debug` — investigation, limited writes
- `/mode review` — strictly read-only code review
- `/mode audit` — security scanning with logging

---

# Memory Bank (Persistent Context)

Per-project memory at `.claude/memory/`:
- `projectContext.md` — What this project is and why
- `activeContext.md` — Current session state (replaces tasks/handoff.md)
- `progress.md` — Task tracking (replaces tasks/todo.md)
- `decisionLog.md` — Architecture decisions with rationale
- `conventions.md` — Learned patterns and mistakes (replaces tasks/lessons.md)
- `sessionHistory.md` — Rolling session summaries

### Task Context (Branch-Specific)
- `.claude/task-context.md` — Per-branch task state (objective, plan, decisions, progress)
- Committed to git for cross-machine handoff
- Auto-loaded by `/session-start` when present
- Auto-updated by `/session-end` when on a feature branch
- Removed when branch merges to main
- Complements Memory Bank: Memory Bank = project-level, task-context = branch-level

**Setup**: Run `/memory-init` in any project to create the structure.
**Usage**: `/session-start` at beginning, `/session-end` at end.

## Session Start Protocol
At the beginning of every working session in a project:
1. Run `/session-start` (loads Memory Bank automatically, falls back to `tasks/` if no Memory Bank)
2. Or manually read: `.claude/memory/activeContext.md`, `progress.md`, `conventions.md`
3. Summarize what you know and confirm direction before diving in

## Session End Protocol
At session end or when approaching 75% context usage:
1. Run `/session-end` (saves everything automatically)
2. Or manually update: `activeContext.md`, `progress.md`, `sessionHistory.md`
3. Commit or stash all work

---

# Core Principles

- **Simplicity First:** Make every change as simple as possible. Impact minimal code.
- **No Laziness:** Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact:** Changes should only touch what's necessary. Avoid introducing bugs.

---

# Learned Patterns

> Universal lessons promoted from project-level `.claude/memory/conventions.md`. These persist across all projects.

### Always commit source files at phase boundaries
Before deploying or moving to the next phase, verify all source files are committed and pushed. Don't assume files are in the repo just because they're on disk.

### Use subagents for Linear/project-management updates
Offload Linear issue creation, status updates, and comments to background subagents. This keeps the main conversation context clean for implementation work.

### Google Drive paths are too slow for Docker builds
Never run `docker build` or `fly deploy` from a Google Drive FUSE-mounted path. Clone to a local temp directory (e.g., `/tmp/`) first — the FUSE latency causes context upload timeouts.

### Phase completion checklist
At the end of every implementation phase: (1) commit + push code, (2) update Linear issues via subagent, (3) use branches for WIP and merge to main at milestones.

### Check for user edits before regenerating output files
When a workflow generates output files (docx, pdf, etc.) that the user may have annotated, always read the output file for comments/edits BEFORE regenerating. Regeneration overwrites user work.

### Em-dashes are an LLM writing tell
When generating prose (especially academic), use em-dashes very sparingly. Prefer commas, parentheses, colons, or sentence restructuring. High em-dash density is a known indicator of LLM-generated text.

### Always update handoff + lessons at phase boundaries
After completing any phase of work (implementation, testing, housekeeping, deployment), immediately update `.claude/memory/activeContext.md` and `.claude/memory/conventions.md`. Don't wait until session end. This ensures context is never lost if a session ends unexpectedly or runs out of context.

### Verify the push target before ANY git push
Always run `git remote -v` and confirm the destination repo matches the user's intent before pushing. Never assume the working directory's remote is the correct push target. The cost of verifying is seconds; the cost of pushing to the wrong repo is trust and potentially broken production.

### Separate products need separate repos from day one
If something has its own Dockerfile, its own deployment config (fly.toml), its own DB migrations, and its own test suite, it is a separate product. Ask about repo strategy before writing the first line of code. Don't develop a new product inside an existing production repo and sort it out later.

### Never push to a production repo without explicit confirmation
Even if the user says "push to GitHub," confirm the specific repo and branch. "Push this" is ambiguous when multiple repos are involved. Show the user `git remote -v` output and get a yes before `git push`.

### Always update README when pushing to main
Every push to main should include README updates for any new features, changed behavior, or new configuration. Don't let documentation drift from the code. Update the README in the same commit or immediately after the feature commit.

### Always check SDK type signatures, not just API docs
When using an SDK that wraps an API, the SDK's public types may differ from the raw API field names (e.g., camelCase `timestampMs` in the SDK vs snake_case `timestamp_ms` in the API). Always read the SDK's type definitions (`.d.ts` files) to confirm the expected input format. Passing raw API field names to an SDK method causes silent `undefined` values and cryptic errors.

### Don't kill processes by port when tunnels share that port
Running `kill $(lsof -ti :PORT)` kills everything connected to that port, including tunnel processes (cloudflared, ngrok) that proxy to it. Always kill by specific PID instead.

### Verify DB column names before writing queries
Never assume column names based on what "makes sense." Always check `information_schema.columns` or the ORM schema first. Getting a column name wrong (e.g., `prolific_pid` vs `participant_id`) causes hard failures and wastes time debugging.

### For non-trivial Node scripts, write to a temp file instead of `-e`
Node.js inline eval (`node -e '...'`) breaks on anything beyond trivial code, especially with special characters, escaping, and newer Node versions. For multi-line scripts with template literals, write to `/tmp/script.mjs` and run that. Saves debugging escaping issues.

### Keep slash command `!` backtick commands simple — no redirects, pipes, or quoted strings
Claude Code's sandbox flags `!` backtick commands in `.claude/commands/*.md` as "multiple operations" if they contain `2>/dev/null`, `| head -N`, `| tail -N`, `| wc -l`, `|| echo "..."`, `|| true`, or quoted strings inside backticks (`--since="8 hours ago"`). Strip all of these. Use git's native flags (e.g., `git log --oneline -10` instead of `git log | head -10`). Let commands fail naturally — Claude handles missing files/repos gracefully without needing `2>/dev/null` fallbacks.

### Linear issue audits must include ALL statuses, not just active
When auditing Linear issues, check Backlog issues too — not just In Progress/Todo. Work often gets done without the issue being moved from Backlog. Cross-reference every issue against the actual DB/codebase state regardless of its Linear status.

### Be precise about data flow direction
When describing data movement, always be explicit: "Source: X → Destination: Y". Saying "copying from X to Y" can be misread. Ambiguous phrasing wastes time on clarification.

### Verify storage layout before destructive operations — never trust cached notes
Symlinks, mount points, and directory layouts change over time. Always verify with `ls -la` and `readlink -f` before proposing deletions. Memory notes about storage go stale fast — a "symlinked" dir may actually be a real dir (or vice versa), and deleting a "backup" could destroy the only copy.

### multiprocessing.Pool.imap_unordered needs chunksize for large workloads
Without `chunksize`, Python serializes the entire iterable into the parent process memory. With tens of thousands of items, the parent can balloon to 10x+ the expected RAM and crash the machine. Always pass a reasonable `chunksize` (e.g., 50-100) and `del` large intermediate lists before spawning the pool.

### Prefer rsync over SSH instead of rsync over CIFS/SMB mounts
Rsync to a CIFS-mounted NAS is dramatically slower (~5 MB/s) than rsync over SSH (~80 MB/s) on the same link due to per-file SMB protocol overhead. Always check if the NAS supports SSH and use `rsync -e ssh` when possible.

### Always test cron commands manually before deploying
Invalid flags (like `--no-delete` for rsync) cause silent failures in cron jobs. Run the exact command interactively first and verify it completes successfully before adding to crontab.

### Validate computed values on a small sample before large backfills
When computing new metrics (angles, distances, scores) across tens of thousands of records, always test on 5-10 samples first and verify the values make sense. Coordinate system conventions (e.g., solvePnP Euler angles wrapping at ±180°) can produce technically correct but semantically wrong results that corrupt the entire dataset.

### Config files must be loaded by the code that creates work items
A config file that defines parameters is useless if the code that creates work items uses a hardcoded list instead. Always verify end-to-end that config values actually reach the consumer. A hardcoded list that shadows a config file will silently diverge — the config becomes dead code.

### Always commit AND PUSH source files at phase boundaries
Before deploying or moving to the next phase, verify all source files are committed and **pushed to the remote**. Don't assume files are in the repo just because they're on disk. Work in `/tmp/` is ephemeral — if a branch isn't pushed, it's lost on reboot. Always `git push -u origin <branch>` after creating a feature branch.
