# Claude Workflow

A shared Claude Code configuration that makes every team member's AI sessions smarter, safer, and continuous. Based on [claude-boris v2.0](https://github.com/llcoolblaze/claude-boris), customized with Linear integration, model-tiered specialist agents (8 core + 44 dev-focused community active, 105 vendored), and cross-machine knowledge syncing.

## Why Use This

Without this workflow, every Claude Code session starts from zero. Claude doesn't remember what you worked on yesterday, doesn't know the mistakes it already made, and has no guardrails when it runs destructive commands. You spend the first 10 minutes of every session re-explaining context. Multiply that across a team and the waste compounds.

This workflow fixes that:

- **No more session amnesia.** The Memory Bank gives Claude persistent context per project. It remembers what was decided, what failed, and what's next. `/session-start` picks up exactly where you left off.

- **Small, structured memory.** The Memory Bank holds only what native auto-memory can't: project identity, architecture decisions, and project-specific conventions. Session continuity is delegated to Claude Code's native auto-memory, so nothing is duplicated and no keyword router is needed.

- **Documentation stays honest.** Drift Detection validates your Memory Bank against the actual codebase -- catching dead file paths, deleted branches, missing dependencies, and stale docs. Zero AI tokens, pure bash. Runs automatically at session start and end.

- **Mistakes happen once, not twice.** When Claude makes a mistake and you correct it, the lesson gets saved to Learned Patterns. Those patterns sync across machines via git, so the entire team benefits from every correction. Claude gets better the more you use it.

- **Specialists that learn your repo.** The recurring specialist agents carry their own persistent memory (`memory: project`), so test-writer remembers your mock factories and oncall-guide accumulates real incident history — they get better at your codebase over time.

- **Safety rails for destructive operations.** Hooks automatically create non-mutating checkpoints before `git reset --hard`, `rm -rf`, or force-pushes, and high-risk `rm -rf` targets require confirmation. Commands and file writes get audit-logged. Claude's own edits are covered by native `/rewind` checkpoints.

- **Complex tasks run themselves.** Instead of manually prompting Claude through multi-step work, `/boris implement user auth` plans the approach, delegates to specialist agents (architect, test-writer), verifies with native `/verify` + `/code-review`, and ships it. A model-tiered roster of specialist agents (cheap models for search/CRUD, stronger models for judgment) keeps delegation fast and cost-efficient.

- **Context travels with branches.** Each feature branch carries a `.claude/task-context.md` with the objective, plan, decisions, and progress. Switch machines, switch people, `git pull` the branch and Claude has full context.

## What You Get

| Category | Count | Highlights |
|---|---|---|
| Core agents | 8 | code-architect (opus), test-writer/doc-generator (sonnet), git-guardian/issue-tracker (haiku), ... — each pinned to a cost-appropriate model tier |
| Community agents | 44 active / 105 vendored | Dev-focused set (engineering, testing, dev design/specialized) installed by default + model-tiered; sales/marketing/product/etc. vendored opt-in |
| Skills | 24 | `/boris` (default for non-trivial tasks), `/clarify`, `/plan-review`, `/cross-review`, `/forge`, `/prime-agent`, `/loops`, `/session-start`, `/checks`, `/bspec-doc`, `/fix-issue`, `/drift-check`, `/handoff`, `/memory-migrate`, and more — same `/name` invocation, now with tool grants, argument hints, and invocation control |
| Workflows | 1 | `boris-build.js` — deterministic multi-agent fan-out engine for large tasks (launched by `/boris`) |
| Hook scripts | 9 | Session auto-loader, destructive ops guard, audit logger, prettier formatter, drift watcher, compaction snapshot, post-compaction recovery, verify gate, plan-approval checkpoint gate |
| Rules | 5 | `git-safety.md`, `workflow.md` (always-on policy), `documentation-channels.md` (Linear + BSpec loop-closing contract), `writing.md` (the Brief block + decision-brief contract, enforced by `ste-check.sh`), `learned-patterns.md` (the lesson-capture/sync target) — installed to `~/.claude/rules/` |
| Settings | -- | Curated permission allowlist, hardened deny list (destructive fs, pipe-to-shell, force-push to main), audit + prettier hooks |
| Plugin (optional) | 1 | `.claude-plugin/` manifest + marketplace so teammates can `/plugin install` (namespaced commands; install.sh stays the bare-name path) |

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/claude-workflow.git ~/Documents/claude-workflow
cd ~/Documents/claude-workflow
chmod +x install.sh sync-lessons.sh uninstall.sh
./install.sh
```

The installer backs up your existing `~/.claude/` config, copies agents/skills/workflows/hooks/rules, removes files retired by newer versions, migrates lessons out of a pre-v3 CLAUDE.md into `~/.claude/lessons/learned-patterns.md`, merges settings (preserving your machine-specific paths and MCP permissions), and syncs Learned Patterns.

Then in any Claude Code session:

```
/session-start          # Orient Claude to your project
/memory-init            # First time in a project? Set up Memory Bank
/boris <describe task>  # Hand off a complex task to the orchestrator
```

### Install as a plugin (optional)

`install.sh` above is the **primary** path — it gives you bare command names (`/task-done`), the full 44-agent community set with model tiering, the `boris-build` saved workflow, and pre-v3 lesson migration.

For teammates who prefer one-line onboarding, the repo also ships as a Claude Code plugin:

```
/plugin marketplace add moverisJustin/claude-workflow
/plugin install boris-workflow@boris
```

The plugin bundles the **24 workflow skills, the 8 model-tiered core agents, and the full safety/audit hook layer**. Two tradeoffs to know:

- **Commands are namespaced** — `/boris-workflow:task-done` instead of `/task-done` (Claude Code always namespaces plugin skills to prevent conflicts; there is no bare-name plugin form).
- **Not included** (use `install.sh` for these): the 44 community agents, the `boris-build` saved workflow, the permission allowlist (plugins can't ship permissions), and the `~/.claude/rules/` lesson-sync files.

Use **one or the other**, not both — running install.sh *and* the plugin would wire the safety hooks twice.

## Daily Workflow

| Situation | Skill |
|---|---|
| Start of day | `/session-start` (loads the Memory Bank, checks drift) |
| New task | `/task-branch feature/auth` then start building |
| Complex task | Just describe it — `/boris` auto-runs the full protocol (plan, delegate, verify, ship) |
| Plan worth a second opinion | `/plan-review` (foreign-model review of the plan before approval; auto-offered when complexity warrants) |
| Bug from Linear | `/fix-issue PROJ-123` |
| What's still in flight? | `/loops` (ledger, delegated tasks/forks, PRs, worktrees, gates) |
| UI work before merge | `/cross-review design` (Codex hunts AI-design tells) |
| Switch focus | Just tell Claude — native auto-memory and the Memory Bank carry the context |
| Before merging | `/checks` then `/code-review medium` then `/commit-push-pr` |
| Something broke | Point Claude at the logs/error (plan mode first for read-only investigation) |
| Task complete | `/task-done` (verify, PR, cleanup) |
| Docs drifting? | `/drift-check` (validates Memory Bank against codebase) |
| Context getting full | `/handoff` (compaction itself is auto-covered by the PreCompact snapshot + post-compaction recovery hooks) |
| End of day | `/session-end` (persists decisions, updates task-context, checks drift) |
| Oops | `/rewind` (Esc-Esc) for Claude's edits; `git reset --soft HEAD^` for a bad commit |

## Key Concepts

### Memory Bank
Each project gets a `.claude/memory/` directory with three **structured, human-authored** files: `projectContext.md` (project identity), `decisionLog.md` (architecture decisions), and `conventions.md` (project-specific conventions and lessons). These hold what native auto-memory doesn't. Session continuity — "where was I", recent work, rolling summaries — is handled by Claude Code's **native auto-memory** (`MEMORY.md` + topic files, loaded every session) plus session resume, so the Memory Bank stays small and doesn't duplicate it.

### Migrating an old project
Returning to a project that still has a pre-v3 Memory Bank (`activeContext`, `progress`, `sessionHistory`, `ROUTER`, `patterns/`, or the older `tasks/` layout)? The SessionStart hook detects it and offers `/memory-migrate`, which salvages real decisions/lessons into the three durable files and **archives** the retired ones (reversible — nothing is deleted). The durable `projectContext`/`decisionLog`/`conventions` files carry over unchanged, so nothing breaks in the meantime.

### Agent Memory
The recurring specialist agents (test-writer, doc-generator, code-architect, oncall-guide) carry `memory: project` — they accumulate this repo's testing patterns, doc structure, architecture, and incident history across sessions, so they get better at *your* codebase over time instead of rediscovering it each run.

### Cross-model memory
Claude auto-loads this repo's memory every session; a foreign model you hand work to (Codex via `/cross-review`, a local model, an Orca agent) does not — so it acts blind to your conventions and ruled-out decisions, and "finds" things you already decided against. `scripts/memory-context.sh` fixes the missing **injection** step (storage was never the problem — it's already model-agnostic markdown): it assembles a portable **memory context pack** — the Memory Bank (identity, conventions, ruled-out decisions) + the active task context + a pitfalls index from `learned-patterns.md` — as Markdown on stdout, ready to prepend to any agent's prompt. `--grep '<keywords>'` scopes the pitfalls to the task at hand; `--full` inlines them all. `/cross-review` runs it automatically so Codex reviews with your standing context in view, and the verify pass drops any finding that merely restates a documented convention. For any *other* handoff — a local model (Ollama, an OpenAI-compatible endpoint), an Orca worktree agent, or a pasted prompt — **`/prime-agent [--grep <topic>] <task>`** assembles the pack plus your task brief, writes `.claude/memory-pack.md`, and copies it to the clipboard ready to pipe or paste. The pack is framed as reference **data, not instructions**, so piping it into another model stays inside the injection boundary. When the branch's `task-context.md` carries a **Task Charter** (Objective / Non-goals / Acceptance / Assumptions), the pack leads with it as the evaluation frame — so every consumer (`/cross-review`, `/plan-review`, `/prime-agent`, `foreign-review.sh` backends) judges against the same source of truth for the task's goals. The `## Assumptions` register is emitted explicitly labelled **UNVERIFIED** — what the work took as true without asking — so foreign reviewers attack those claims instead of inheriting them; `spec-drift` treats a false assumption as a finding alongside drift and scope creep.

### External review (multi-model)
A model reviewing its own family's output inherits the biases that created the bugs. The workflow adds decorrelated foreign-model review at **two points**:

- **Plan stage — `/plan-review`.** Runs inside plan mode, after the `/clarify` and `/anythingelse` checkpoints and before approval. Auto-offered only when the plan clears a complexity bar (multi-module, architectural decisions, or financial/data-integrity/security surface); manually invocable any time. Backends review the plan pack in parallel, Claude adversarially verifies every finding, disagreements are resolved through explicit decision gates, and the reconciled plan gets **one** approval.
- **PR stage — `/cross-review pr`.** An optional gate in `/task-done` after `/checks` is green. Backends review the branch per the routing table; findings are mechanically merged (dedup + agreement marking), adversarially verified, and reported issues-only (terminal + `.claude/reviews/`, gitignored). Posting to the PR or Linear happens only behind explicit flags.

**Routing** lives in `skills/cross-review/review-backends.json`: **Codex** takes correctness + design; **Kimi** (via OpenRouter, long context) takes spec-drift + architecture + test-gap. Native `/code-review` and `/security-review` are **prerequisites**, not merge participants — they run first and appear in the report footer, never mixed into foreign-finding stats.

**One runner, fail-loud**: `scripts/foreign-review.sh` is the backend-agnostic entry point (`--backend codex|openrouter:<model> --mode plan|code --schema FILE --input FILE`). Its contract: a missing backend, failed call, or schema-invalid response is reported loudly with a distinct exit code — never fabricated, never silently substituted with a same-family review. Raw backend output is always preserved (`<out>.raw`); the validated result is written only on success. Before anything leaves the machine, a payload preflight discloses provider/endpoint/size and a secret scrub hard-stops on key-shaped content.

**Shared evaluation frame**: every reviewer — Claude included — judges against the **Task Charter**, which `memory-context.sh` emits as the first section of every pack (see Cross-model memory above). One source of truth for the task's goals.

**Setup (OpenRouter/Kimi backend)** — the only secret lives in `~/.claude/foreign-review.env` (user-created, `chmod 600`, never committed and never deployed by install.sh; it contains `OPENROUTER_API_KEY` and nothing else). Model ids are config, not secrets — they live in `review-backends.json`. Codex uses your existing Codex CLI auth.

**Calibration ledger**: every review run appends a versioned event (backend, exact model id, schema version, prompt hash, raised/confirmed/plausible/refuted counts — CONFIRMED and PLAUSIBLE tracked separately, never pooled) to `~/.claude/reviews/backend-stats.jsonl`, and report footers show cumulative precision per backend ("codex/correctness: 62% confirmed over 34 findings"). Routing-table changes stay human decisions informed by those numbers.

**Foreign writes are opt-in, propose-only by default**: reviews are read-only. With explicit per-instance authorization from you (a gate option or direct instruction, never automatic), a CLI-backed foreign agent can be handed fix work inside the task worktree — it edits files but never commits or pushes. Claude adversarially reviews the foreign diff, runs `/checks`, and commits with source attribution; foreign-proposed lessons stay proposals until main-context Claude validates and writes them.

### Drift Detection
`/drift-check` validates that your Memory Bank, `CLAUDE.md`, and project `.claude/rules/` still match reality. Five static checkers (zero AI tokens, pure bash) catch dead file paths, deleted branches, missing dependencies, stale docs, and undefined commands. The path checker only treats tokens with a real file extension as references and resolves each one against the repo tree, sibling repo checkouts, and the repo's own docs before flagging (retired pre-v3 memory files are skipped), so prose tokens and cross-repo mentions don't count as drift. The dependency checker warns only when a dependency-shaped signal sits adjacent to a backticked token (`pip install`, `import`, "the X library"), so table names, CLI flags, and timezones in backticks aren't package claims. Scoring starts at 100 and deducts per finding. Integrated into `/session-start` (warns if score drops below 80) and `/session-end` (catches drift introduced by the session itself). A post-commit hook alerts on regressions.

### Self-Audit (this repo's own maintenance)
`scripts/maintenance-check.sh` re-counts the real agents / skills / hooks / community agents and compares them to the numbers the README and CHEATSHEET claim — the exact drift this repo suffered before ("15 agents, 23 commands" in the docs while reality had moved on). It runs in CI on every PR (so a count can never silently drift again) and can be scheduled locally for ongoing hygiene:

```bash
scripts/maintenance-check.sh                # audit now
scripts/maintenance-check.sh --install-cron # weekly local cron (Mondays 09:00)
```

No cloud usage; pure bash, zero AI tokens.

### BSpec Documents
`/bspec-doc` auto-fires whenever you ask for a spec, PRD, feature spec, architecture/system/API/data/security doc, or decision record, and writes it as a saved file in the standardized [BSpec](https://bspec.dev) format (YAML-frontmatter Markdown with a shared type vocabulary and typed cross-links) so specs stay consistent across the company. Claude authors the document directly — no external LLM — then `scripts/bspec-validate.sh` checks it offline: required fields, a real BSpec type code, a valid status, and no dangling relationship links. The released BSpec CLI has no offline validate/generate (its only such path needs an external OpenRouter/OpenAI key), so validation is our own zero-dependency script; the CLI itself is optional corpus tooling (`bspec init/pack/open/query`) installed on demand via `scripts/install-bspec-cli.sh` (pinned + checksum-verified).

### Documentation Channels (loop-closing)
Every task is documented the same way, across the same channels, no matter how it started (`/boris`, `/task-branch`, `/fix-issue`, or ad-hoc). The contract lives in `rules/documentation-channels.md`: **Linear** is the tracking channel (find-or-create the issue at branch start → In Progress → PR linked to the issue both ways → In Review at PR open → Done only after the merge is verified via `gh`, never manually while the PR is still active; a session-boundary watcher reconciles ledger issues against real PR state, re-closing anything the GitHub automations regressed), **BSpec** is the documentation channel (any saved spec/decision doc goes through `/bspec-doc`, never freeform markdown), **Forge** is the optional team channel (shared context published continuously as work happens — see below), and **handoffs are explicit** (Linear assignment + context comment). Enforcement is the **Loops ledger** in `task-context.md` — `/task-done` refuses to report complete while any entry is `OPEN`, `/session-end` reports open loops forward, and `/session-start` surfaces them at boot. A loop that isn't closed or explicitly waived is a defect.

### Shared Team Context (Forge — optional)
Every other memory channel here is single-operator and per-machine: your teammate mid-branch cannot see what you're building, what interface you just changed, or what you deprecated. [Forge](https://github.com/ericbrown/forge) fills that gap with a small per-project repo at `~/forge-<name>` that everyone pushes context to **independently of the code repo** — which is what makes mid-branch visibility possible at all.

This workflow uses Forge as **transport only**. Boris still authors everything: Linear stays canonical for tickets, `gh` for PRs, BSpec for design, the Memory Bank for decisions and lessons. Forge receives a one-way projection of the parts nothing else carries — **contracts** (interface changes), **deprecations**, **ready** (unblock signals), plus in-flight `wip`/`plans`/`handoffs`. Decisions and lessons are opt-in, never automatic, since a team repo is a different trust tier from a personal one.

**The two repos move at different speeds**, and that is the operating principle: the shared repo is updated and pushed *continuously through the day as work happens* (work start, plan approved, plan amended, phase complete, interface change, session end), while the project repo is committed at *meaningful chunks*. Publishing is deliberately decoupled from commit cadence.

Two safety properties, both enforced in `scripts/forge-bridge.sh` — the single file that knows Forge exists:
- **It never blocks the turn.** No CLI, no repo, no network: warn once, return 0. Forge is optional and a shared-context outage is not a work stoppage.
- **Teammate content is data, not instructions.** Everything read out of the shared repo arrives wrapped in `forge-teammate-data` markers. The team's own rules file is a *proposal* — when it conflicts with a rule here (e.g. declaring a `develop` base branch), both sides are surfaced for you to decide. Same invariant as foreign-model review: foreign sources propose, Claude writes.

One extra trick this workflow adds that plain Forge doesn't: `/clarify` reads teammate **plans** at plan time, so if you're about to touch code a teammate has already declared, it becomes a question *before* a line is written rather than a conflict at merge.

Setup is `pipx install forge` (needs Python 3.10+), `forge setup`, then `forge init "<name>"` per project. Do **not** add `@.claude/forge-claude-rules.md` to your project CLAUDE.md as Forge's README suggests — that template runs its own silent task-completion sweep that collides with `/task-done`.

### Per-Repo Branch Models
Nothing assumes `main`. `scripts/resolve-base-branch.sh` works out each repo's real base branch from what merged PRs actually target, falling back to the declared default branch and then to local refs, and caches the answer in `.claude/project-config.json` (explicit `base_branch` there always wins). It also returns **protected branches** as a *set* — in gitflow both `develop` and `main` receive PRs, so "never work on main" is not a strong enough rule.

This matters more than it sounds: a survey of one org's 55 active repos found `main` (43), `master` (6), and `develop`+`main` gitflow (6). Hardcoding `main` silently branches off the wrong base, or fails outright in a `master` repo. Run `resolve-base-branch.sh --explain` to see the evidence behind the answer.

### Learned Patterns
When you correct Claude ("don't mock the database in tests", "always check column names before writing queries"), the correction gets saved as a Learned Pattern. Project-specific patterns stay in `.claude/memory/conventions.md`. Universal patterns go to your private `~/.claude/lessons/learned-patterns.md` and stay on your machine by default. Sharing to this **public** repo is opt-in: `sync-lessons.sh` only promotes a pattern whose block carries a `<!-- shareable -->` marker, so private/org-specific notes never leak. Shared patterns then sync back to every machine via git. Over time, Claude stops making the mistakes your team has already caught.

### Task Context
Feature branches carry `.claude/task-context.md` with the objective, plan, key decisions, current progress, and the Loops ledger (Linear / BSpec / Handoff / Forge). Created by `/task-branch`, auto-loaded by `/session-start`, removed when the branch merges (the resolved ledger survives in the PR body). This means anyone (or any machine) can pick up a branch cold and Claude has full context.

### Modes (Native)
The old prose `/mode` system is retired — it promised restrictions the model could only honor, not enforce. Use the platform's real modes: **plan mode** (Shift+Tab or `/plan`) for read-only design and review — enforced by the harness, not by a promise — default/acceptEdits permission modes for implementation, the audit hooks for a real command/file-write trail, and `/security-review` for the security pass.

---

## Reference

> Full reference with all details: **[CHEATSHEET.md](CHEATSHEET.md)**

### Skills (invoke as `/name`)

| Skill | What it does |
|---|---|
| `/boris <task>` | Full orchestrated workflow -- plan, delegate, verify, ship. **Auto-invoked by default** for any non-trivial task |
| `/plan-review` | Foreign-model review of the current plan inside plan mode (fail-loud, adversarially verified, reconciled before the one approval); auto-offered above the complexity bar |
| `/cross-review [code\|design\|pr]` | Adversarial review by a different model family (decorrelated blind spots); `design` mode hunts "looks like AI design" tells; `pr` mode fans out to all routed backends (Codex + Kimi) and merges verified findings |
| `/loops` | One board of everything open: Loops ledger, delegated tasks/forks, PRs, worktrees, stashes, armed gates |
| `/session-start` | Load Memory Bank, check project status, orient to continue |
| `/session-end` | Save Memory Bank state, create session summary for next time |
| `/checks` | Stack-detected quality gates (tests, types, lint, format, build) with a Stop-hook verify gate |
| `/task-branch <name>` | Create feature branch with task context for cross-machine handoff |
| `/task-done` | Complete task: verify, create PR, clean up task-context.md |
| `/commit-push-pr` | Stage, commit, push, create PR -- full git workflow |
| `/quick-commit` | Fast local commit with auto-generated message (no push) |
| `/fix-issue <id>` | Fetch issue from Linear/GitHub, implement fix, create PR |
| `/ci-loop` | Push, watch CI in the background (no blocked turn), fix failures, repeat until green |
| `/memory-init` | Initialize Memory Bank for a new project |
| `/handoff` | Cognitive briefing -- saves mental model, failed approaches, resume prompt |
| `/drift-check` | Validate Memory Bank accuracy against codebase, suggest and auto-fix drift |
| `/update-claude-md` | Capture learnings into CLAUDE.md from recent work |
| `/bspec-doc` | Author a spec/PRD/feature/architecture/decision doc in the standardized BSpec format, then validate it offline |
| `/memory-migrate` | Convert a project's pre-v3 Memory Bank to the v3 model (salvage decisions/lessons, archive retired files) |
| `/first-principles` | Break down a complex problem from fundamentals |
| `/clarify` | Batched six-axis question sweep at the user — auto-runs at the start of every planning phase and on any gap found during execution |
| `/anythingelse` | Creative wildcard prompt — auto-runs at the end of every planning phase |
| `/forge` | Shared team context — see what teammates are building right now, publish work-in-progress, broadcast interface changes and deprecations (optional; no-ops without Forge) |

Retired in favor of native Claude Code features: `/verify-all` + `/test-and-fix` → `/verify` + `/checks`; `/review-changes` → `/code-review <effort>` (`ultra` for cloud review); `/security-scan` → `/security-review`; `/undo`/`/checkpoint`/`/rollback` → `/rewind`; `/mode` → native plan/permission modes; `/context` → native `/context` + statusline.

### Core Agents (8)

Boris itself is a **skill** now (`skills/boris/SKILL.md`), not an agent — the 2025 persona-indirection hack (main thread "becoming" boris by reading an agent file) is gone. It plans in native plan mode, delegates via the Agent tool (forks, background agents, worktree isolation), and launches the `boris-build` saved Workflow for fan-out-scale jobs.

| Agent | Role |
|---|---|
| **code-architect** | System design, architecture decisions, technical planning |
| **test-writer** | Generate comprehensive tests (JS/TS/Python) |
| **doc-generator** | Generate/update README, API docs, CLAUDE.md |
| **issue-tracker** | Linear/GitHub issue management and lifecycle |
| **git-guardian** | Git safety -- push-target/staging verification, branch protection |
| **memory-bank** | Cross-session context persistence |
| **oncall-guide** | Production incident debugging and rapid resolution |
| **linear-project-manager** | Linear-native issue, sprint, and project management |

Six former agents are native features now: code-simplifier → `/simplify`, verify-app → `/verify` + `/checks`, pr-reviewer → `/code-review`, security-auditor → `/security-review`, mode-controller → native plan/permission modes, audit-logger → the PreToolUse audit hooks. Native versions are harness-enforced and independently verified -- strictly better than the prompt-based agents they replace.

### Community Agents (44 active / 105 vendored)

Sourced from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) (pinned to a reviewed commit). All 105 are vendored, but only the **dev-focused set installs by default**; the rest are opt-in.

| Category | Active | Vendored | Default? |
|---|---|---|---|
| Engineering | 21 | 21 | ✅ active |
| Testing & QA | 8 | 8 | ✅ active |
| Design (UX/UI) | 3 | 8 | ✅ active (brand/visual opt-in) |
| Specialized (dev/technical) | 12 | 15 | ✅ active (non-dev opt-in) |
| Sales / Marketing / Product / PM | 0 | 32 | opt-in |
| Support / Game Dev / Paid Media | 0 | 21 | opt-in |

Manage community agents by editing `agents/community/MANIFEST.txt`: uncomment an opt-in agent and re-run `install.sh` to enable it (offline), or run `scripts/sync-agency-agents.sh` to refresh the vendored files from upstream. install.sh installs only the active (uncommented) agents and applies a model tier to each (dev personas → sonnet, advisory → haiku + read-only tools) at deploy time.

### Hooks (Automatic)

| Hook | Trigger | What it does |
|---|---|---|
| **SessionStart loader** | Every new session | Auto-loads project name, branch, task-context objective, drift/signing warnings |
| **Destructive ops guard** | Before `git reset --hard`, `rm -rf`, force-push | Creates a non-mutating checkpoint (tag + `git stash create` snapshot — the working tree is never touched); escalates to a confirmation prompt for high-risk `rm -rf` targets (absolute paths, `~`, `..`, `*`) |
| **Audit logger** | Before Bash / Edit / Write | Appends a command and file-write trail to `.claude/audit/` |
| **Drift watcher** | After `git commit` | Runs drift check, alerts Claude if the Memory Bank score drops below 80 |
| **Prettier formatter** | After Edit/Write of js/ts/css/md files | Formats with the project's own prettier; projects without prettier are skipped |
| **Compaction snapshot** | Before context compaction | Writes a git-state snapshot (branch, uncommitted files, recent commits) to `.claude/memory/compaction-snapshot.md` |
| **Post-compaction recovery** | After context compaction | Injects a directive to verify the summary against the snapshot and save a cognitive handoff to `task-context.md` |
| **Verify gate** | Turn end (Stop), only while `/checks` has the gate armed | Blocks ending the turn until quality gates pass or are explicitly waived; 3-attempt escape hatch, 2h staleness disarm |
| **Plan-approval gate** | Before `ExitPlanMode`, on task branches only | **Denies** plan approval until `/clarify` and `/anythingelse` have actually run this plan episode. `/plan-review` is **advisory** — named in the denial text when absent, but never blocking on its own, because recording its waiver means editing `task-context.md`, which plan mode forbids. Evidence is read from the session transcript, not from a self-report — a checkpoint record in `task-context.md` is one edit from being forged, and plan mode cannot write that file anyway. 3-denial escape hatch (`GATE_MAX_DENIALS` overrides the count). Uses `deny` because `ask` is silently discarded on this tool |
| **Publish gate** | Before `git push` / `gh pr create`, on task branches only | Asks when the charter's `cross-review` checkpoint is still open. This is the mechanical containment that makes `/task-done` safe to auto-invoke — a skill instructing itself to stop and ask is the exact class of instruction that measurably does not run |

Hooks read the tool payload as JSON on stdin per the current Claude Code hooks contract and are covered by `scripts/test-hooks.sh` in CI, so a contract change can never silently disable them again.

The SessionStart hook also detects new projects (no `.claude/project-config.json`) and prompts you to run `/memory-init`. Non-git projects can set `"git_enabled": false` in `.claude/project-config.json`.

## Customization

- **Add core agents**: Create `.md` files in `agents/` with frontmatter (`name`, `description`, `tools`)
- **Add/remove community agents**: Edit `agents/community/MANIFEST.txt` (uncomment to enable, comment to disable) and re-run `install.sh`; use `scripts/sync-agency-agents.sh` to refresh from upstream
- **Add skills**: Create `skills/<name>/SKILL.md` with frontmatter (`description`, optional `disable-model-invocation`, `allowed-tools`, `argument-hint`); invoke as `/name`. Supporting files can live in the skill's directory.
- **Add rules**: Drop always-on policy files in `~/.claude/rules/*.md` (project-level: `.claude/rules/`; add `paths:` frontmatter to scope a rule to matching files)
- **Machine-specific settings**: Edit `~/.claude/settings.json` directly for paths, plugins, MCP permissions. These are preserved across `install.sh` runs.
- **New lessons**: Just work with Claude -- lessons are added to your private `~/.claude/lessons/learned-patterns.md` during sessions (`/update-claude-md` routes them). To publish one to this public repo, add a `<!-- shareable -->` marker under its `### ` heading, then run `sync-lessons.sh` (untagged lessons stay local)

## Sync Lessons Across Machines

Learned Patterns are universal lessons that accumulate as Claude makes mistakes and you correct them. They persist across all projects and live in your private `~/.claude/lessons/learned-patterns.md` (Boris v3 moved them out of CLAUDE.md to keep it under the ~200-line adherence budget; `install.sh` migrates old machines automatically).

Promotion to this **public** repo is **opt-in**. A lesson is pushed to the repo's `rules/learned-patterns.md` only if its block contains a `<!-- shareable -->` marker; everything else stays on your machine. This keeps private/org-specific notes (production hosts, internal tooling, client names) out of the public repo by default.

**Mark a lesson shareable** -- add the marker on the line under its heading in `~/.claude/lessons/learned-patterns.md`:
```markdown
### Always run migrations inside a transaction
<!-- shareable -->
Wrap schema changes in BEGIN/COMMIT so a failed migration rolls back cleanly.
```

**After a work session (any machine):**
```bash
cd ~/Documents/claude-workflow
./sync-lessons.sh   # promotes only <!-- shareable --> lessons; reports what it kept local
git add lessons/learned-patterns.md && git commit -m "sync lessons" && git push
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
