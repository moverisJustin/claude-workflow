# Claude Workflow

A shared Claude Code configuration that makes every team member's AI sessions smarter, safer, and continuous. Based on [claude-boris v2.0](https://github.com/llcoolblaze/claude-boris), customized with Linear integration, 114 specialist agents (9 core + 105 community), and cross-machine knowledge syncing.

## Why Use This

Without this workflow, every Claude Code session starts from zero. Claude doesn't remember what you worked on yesterday, doesn't know the mistakes it already made, and has no guardrails when it runs destructive commands. You spend the first 10 minutes of every session re-explaining context. Multiply that across a team and the waste compounds.

This workflow fixes that:

- **No more session amnesia.** The Memory Bank gives Claude persistent context per project. It remembers what was decided, what failed, and what's next. `/session-start` picks up exactly where you left off.

- **Smart context loading.** The Context Router loads only the memory files relevant to your current task (2-3 files instead of all 6+). A debug task loads conventions and decision log; a new feature loads project context and patterns. Less token waste, better AI attention.

- **Documentation stays honest.** Drift Detection validates your Memory Bank against the actual codebase -- catching dead file paths, deleted branches, missing dependencies, and stale docs. Zero AI tokens, pure bash. Runs automatically at session start and end.

- **Mistakes happen once, not twice.** When Claude makes a mistake and you correct it, the lesson gets saved to Learned Patterns. Those patterns sync across machines via git, so the entire team benefits from every correction. Claude gets better the more you use it.

- **Patterns compound from real work.** After each session, the GROW step evaluates whether the task should become a reusable pattern. Over time, your project accumulates step-by-step guides for common task types (adding an API endpoint, debugging a pipeline, writing integration tests).

- **Safety rails for destructive operations.** Hooks automatically create non-mutating checkpoints before `git reset --hard`, `rm -rf`, or force-pushes, and high-risk `rm -rf` targets require confirmation. Commands and file writes get audit-logged. Claude's own edits are covered by native `/rewind` checkpoints.

- **Complex tasks run themselves.** Instead of manually prompting Claude through multi-step work, `/boris implement user auth` plans the approach, delegates to specialist agents (architect, test-writer), verifies with native `/verify` + `/code-review`, and ships it. 110+ agents cover engineering, design, sales, marketing, product, QA, and more.

- **Context travels with branches.** Each feature branch carries a `.claude/task-context.md` with the objective, plan, decisions, and progress. Switch machines, switch people, `git pull` the branch and Claude has full context.

## What You Get

| Category | Count | Highlights |
|---|---|---|
| Core agents | 9 | code-architect, test-writer, doc-generator, oncall-guide, git-guardian, linear-project-manager |
| Community agents | 105 | Engineering, design, sales, marketing, product, PM, QA, support, game dev, paid media, specialized |
| Skills | 17 | `/boris`, `/session-start`, `/checks`, `/fix-issue`, `/task-branch`, `/drift-check`, `/load-context`, and more — same `/name` invocation, now with tool grants, argument hints, and invocation control |
| Workflows | 1 | `boris-build.js` — deterministic multi-agent fan-out engine for large tasks (launched by `/boris`) |
| Hook scripts | 8 | Session auto-loader, destructive ops guard, audit logger, prettier formatter, drift watcher, compaction snapshot, post-compaction recovery, verify gate |
| Context templates | 2 | ROUTER.md (context routing), patterns/INDEX.md (pattern registry) |
| Settings | -- | Wildcard permissions, Prettier hook, audit logging, deny list for dangerous ops |

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/claude-workflow.git ~/Documents/claude-workflow
cd ~/Documents/claude-workflow
chmod +x install.sh sync-lessons.sh uninstall.sh
./install.sh
```

The installer backs up your existing `~/.claude/` config, copies agents/skills/workflows/hooks, removes files retired by newer versions, merges settings (preserving your machine-specific paths and MCP permissions), and syncs Learned Patterns.

Then in any Claude Code session:

```
/session-start          # Orient Claude to your project
/memory-init            # First time in a project? Set up Memory Bank
/boris <describe task>  # Hand off a complex task to the orchestrator
```

## Daily Workflow

| Situation | Skill |
|---|---|
| Start of day | `/session-start` (routes to task-relevant context, checks drift) |
| New task | `/task-branch feature/auth` then start building |
| Complex task | `/boris implement user authentication` |
| Bug from Linear | `/fix-issue PROJ-123` |
| Switch task type | `/load-context debug` or `/load-context deploy` |
| Before merging | `/checks` then `/code-review medium` then `/commit-push-pr` |
| Something broke | Point Claude at the logs/error (plan mode first for read-only investigation) |
| Task complete | `/task-done` (verify, PR, cleanup) |
| Docs drifting? | `/drift-check` (validates Memory Bank against codebase) |
| Context getting full | `/handoff` (compaction itself is auto-covered by the PreCompact snapshot + post-compaction recovery hooks) |
| End of day | `/session-end` (saves state, grows patterns, checks drift) |
| Oops | `/rewind` (Esc-Esc) for Claude's edits; `git reset --soft HEAD^` for a bad commit |

## Key Concepts

### Memory Bank
Each project gets a `.claude/memory/` directory with persistent files: project context, active session state, progress tracking, decision log, conventions, session history, and a context router. Claude reads these at session start and writes them at session end. The result is continuity across sessions without you re-explaining anything.

### Context Router
`ROUTER.md` is loaded first every session. It classifies your task by keywords and loads only the 2-3 relevant memory files instead of everything. A debug task loads conventions and the decision log. A new feature loads project context and the pattern index. This keeps token usage low and AI attention focused. Auto-generated for existing projects on their first session after install -- no manual setup required. Use `/load-context <type>` to switch context mid-session.

### Drift Detection
`/drift-check` validates that your Memory Bank still matches reality. Five static checkers (zero AI tokens, pure bash) catch dead file paths, deleted branches, missing dependencies, stale docs, and undefined commands. Scoring starts at 100 and deducts per finding. Integrated into `/session-start` (warns if score drops below 80) and `/session-end` (catches drift introduced by the session itself). Optional post-commit hook for continuous monitoring.

### Task Patterns
Patterns are task-specific step-by-step guides that accumulate from real work. After each session, the GROW step in `/session-end` evaluates whether the task should become a reusable pattern (e.g., "add an API endpoint", "debug a streaming pipeline"). Patterns are registered in `patterns/INDEX.md` and loaded on demand by the router when a matching task comes up. Over time, your project builds a playbook that makes repeated task types faster.

### Learned Patterns
When you correct Claude ("don't mock the database in tests", "always check column names before writing queries"), the correction gets saved as a Learned Pattern. Project-specific patterns stay in `.claude/memory/conventions.md`. Universal patterns go to your private `~/.claude/CLAUDE.md` and stay on your machine by default. Sharing to this **public** repo is opt-in: `sync-lessons.sh` only promotes a pattern whose block carries a `<!-- shareable -->` marker, so private/org-specific notes never leak. Shared patterns then sync back to every machine via git. Over time, Claude stops making the mistakes your team has already caught.

### Task Context
Feature branches carry `.claude/task-context.md` with the objective, plan, key decisions, and current progress. Created by `/task-branch`, auto-loaded by `/session-start`, removed when the branch merges. This means anyone (or any machine) can pick up a branch cold and Claude has full context.

### Modes (Native)
The old prose `/mode` system is retired — it promised restrictions the model could only honor, not enforce. Use the platform's real modes: **plan mode** (Shift+Tab or `/plan`) for read-only design and review — enforced by the harness, not by a promise — default/acceptEdits permission modes for implementation, the audit hooks for a real command/file-write trail, and `/security-review` for the security pass.

---

## Reference

> Full reference with all details: **[CHEATSHEET.md](CHEATSHEET.md)**

### Skills (invoke as `/name`)

| Skill | What it does |
|---|---|
| `/boris <task>` | Full orchestrated workflow -- plan, delegate, verify, ship |
| `/session-start` | Load Memory Bank, check project status, orient to continue |
| `/session-end` | Save Memory Bank state, create session summary for next time |
| `/checks` | Stack-detected quality gates (tests, types, lint, format, build) with a Stop-hook verify gate |
| `/task-branch <name>` | Create feature branch with task context for cross-machine handoff |
| `/task-done` | Complete task: verify, create PR, clean up task-context.md |
| `/commit-push-pr` | Stage, commit, push, create PR -- full git workflow |
| `/quick-commit` | Fast local commit with auto-generated message (no push) |
| `/fix-issue <id>` | Fetch issue from Linear/GitHub, implement fix, create PR |
| `/ci-loop` | Push, wait for CI, parse failures, fix, repeat |
| `/memory-init` | Initialize Memory Bank for a new project |
| `/handoff` | Cognitive briefing -- saves mental model, failed approaches, resume prompt |
| `/load-context <type>` | Load task-specific context mid-session (feature/debug/test/deploy/etc) |
| `/drift-check` | Validate Memory Bank accuracy against codebase, suggest and auto-fix drift |
| `/update-claude-md` | Capture learnings into CLAUDE.md from recent work |
| `/first-principles` | Break down a complex problem from fundamentals |
| `/anythingelse` | Creative wildcard prompt |

Retired in favor of native Claude Code features: `/verify-all` + `/test-and-fix` → `/verify` + `/checks`; `/review-changes` → `/code-review <effort>` (`ultra` for cloud review); `/security-scan` → `/security-review`; `/undo`/`/checkpoint`/`/rollback` → `/rewind`; `/mode` → native plan/permission modes; `/context` → native `/context` + statusline.

### Core Agents (9)

Boris itself is a **skill** now (`skills/boris/SKILL.md`), not an agent — the 2025 persona-indirection hack (main thread "becoming" boris by reading an agent file) is gone. It plans in native plan mode, delegates via the Agent tool (forks, background agents, worktree isolation), and launches the `boris-build` saved Workflow for fan-out-scale jobs.

| Agent | Role |
|---|---|
| **code-architect** | System design, architecture decisions, technical planning |
| **test-writer** | Generate comprehensive tests (JS/TS/Python) |
| **doc-generator** | Generate/update README, API docs, CLAUDE.md |
| **ci-integrator** | CI pipeline automation -- push, monitor, fix, iterate |
| **issue-tracker** | Linear/GitHub issue management and lifecycle |
| **git-guardian** | Git safety -- push-target/staging verification, branch protection |
| **memory-bank** | Cross-session context persistence |
| **oncall-guide** | Production incident debugging and rapid resolution |
| **linear-project-manager** | Linear-native issue, sprint, and project management |

Six former agents are native features now: code-simplifier → `/simplify`, verify-app → `/verify` + `/checks`, pr-reviewer → `/code-review`, security-auditor → `/security-review`, mode-controller → native plan/permission modes, audit-logger → the PreToolUse audit hooks. Native versions are harness-enforced and independently verified -- strictly better than the prompt-based agents they replace.

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
| **Destructive ops guard** | Before `git reset --hard`, `rm -rf`, force-push | Creates a non-mutating checkpoint (tag + `git stash create` snapshot — the working tree is never touched); escalates to a confirmation prompt for high-risk `rm -rf` targets (absolute paths, `~`, `..`, `*`) |
| **Audit logger** | Before Bash / Edit / Write | Appends a command and file-write trail to `.claude/audit/` |
| **Drift watcher** | After `git commit` | Runs drift check, alerts Claude if the Memory Bank score drops below 80 |
| **Prettier formatter** | After Edit/Write of js/ts/css/md files | Formats with the project's own prettier; projects without prettier are skipped |
| **Compaction snapshot** | Before context compaction | Writes a git-state snapshot (branch, uncommitted files, recent commits) to `.claude/memory/compaction-snapshot.md` |
| **Post-compaction recovery** | After context compaction | Injects a directive to verify the summary against the snapshot and save a cognitive handoff to `task-context.md` |
| **Verify gate** | Turn end (Stop), only while `/checks` has the gate armed | Blocks ending the turn until quality gates pass or are explicitly waived; 3-attempt escape hatch, 2h staleness disarm |

Hooks read the tool payload as JSON on stdin per the current Claude Code hooks contract and are covered by `scripts/test-hooks.sh` in CI, so a contract change can never silently disable them again.

The SessionStart hook also detects new projects (no `.claude/project-config.json`) and prompts you to run `/memory-init`. Non-git projects can set `"git_enabled": false` in `.claude/project-config.json`.

## Customization

- **Add core agents**: Create `.md` files in `agents/` with frontmatter (`name`, `description`, `tools`)
- **Add/remove community agents**: Edit `agents/community/MANIFEST.txt` and run `scripts/sync-agency-agents.sh`
- **Add skills**: Create `skills/<name>/SKILL.md` with frontmatter (`description`, optional `disable-model-invocation`, `allowed-tools`, `argument-hint`); invoke as `/name`. Supporting files can live in the skill's directory.
- **Machine-specific settings**: Edit `~/.claude/settings.json` directly for paths, plugins, MCP permissions. These are preserved across `install.sh` runs.
- **New lessons**: Just work with Claude -- lessons are added to your private `~/.claude/CLAUDE.md` during sessions. To publish one to this public repo, add a `<!-- shareable -->` marker under its `### ` heading, then run `sync-lessons.sh` (untagged lessons stay local)

## Sync Lessons Across Machines

Learned Patterns are universal lessons that accumulate as Claude makes mistakes and you correct them. They persist across all projects and live in your private `~/.claude/CLAUDE.md`.

Promotion to this **public** repo is **opt-in**. A lesson is pushed to the repo's `CLAUDE.md` only if its block contains a `<!-- shareable -->` marker; everything else stays on your machine. This keeps private/org-specific notes (production hosts, internal tooling, client names) out of the public repo by default.

**Mark a lesson shareable** -- add the marker on the line under its heading in `~/.claude/CLAUDE.md`:
```markdown
### Always run migrations inside a transaction
<!-- shareable -->
Wrap schema changes in BEGIN/COMMIT so a failed migration rolls back cleanly.
```

**After a work session (any machine):**
```bash
cd ~/Documents/claude-workflow
./sync-lessons.sh   # promotes only <!-- shareable --> lessons; reports what it kept local
git add CLAUDE.md && git commit -m "sync lessons" && git push
```

**On another machine:**
```bash
cd ~/Documents/claude-workflow
git pull
./sync-lessons.sh
```

How it works: bidirectional merge by `### Heading` deduplication. **Local -> repo** is opt-in (only `<!-- shareable -->`-tagged lessons promote). **Repo -> local** pulls every shared lesson down so it takes effect locally. Never overwrites or removes existing lessons. Verify the privacy guard any time with `./test-sync-lessons.sh`.

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
