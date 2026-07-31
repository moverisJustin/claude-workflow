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
After completing any phase of work (implementation, testing, housekeeping, deployment), immediately persist context: update `.claude/memory/conventions.md` with any new lessons and — on a feature branch — `.claude/task-context.md` with the handoff briefing. Don't wait until session end. Session state itself is carried by native auto-memory. This ensures context is never lost if a session ends unexpectedly or runs out of context.

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
Claude Code's sandbox flags `!` backtick commands in skill/command markdown (`skills/*/SKILL.md`, legacy `.claude/commands/*.md`) as "multiple operations" if they contain `2>/dev/null`, `| head -N`, `| tail -N`, `| wc -l`, `|| echo "..."`, `|| true`, or quoted strings inside backticks (`--since="8 hours ago"`). Strip all of these. Use git's native flags (e.g., `git log --oneline -10` instead of `git log | head -10`). Let commands fail naturally — Claude handles missing files/repos gracefully without needing `2>/dev/null` fallbacks.

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

### Update README on session-end, not just Memory Bank
On `/session-end`, update README.md (and CHEATSHEET.md if relevant) alongside Memory Bank files. The README is the first thing people see on the repo — if it doesn't reflect the current state, new users and future sessions start with a wrong mental model. Memory Bank is for Claude; README is for humans. Both must stay in sync.

### Never re-propose approaches that have been ruled out
If conventions.md or memory documents say an approach doesn't work or is infeasible, DO NOT suggest it again. Read conventions at session start and respect established constraints. Re-proposing ruled-out approaches wastes the user's time and erodes trust. The entire point of the memory bank is to prevent repeating mistakes.

### Claude Code permission wildcard `(*)` only works for Bash
In settings.json permissions, `ToolName(*)` is ONLY valid for Bash (e.g., `Bash(git *)`). For all other tools — Read, Glob, Grep, Task, WebFetch, WebSearch — use the bare tool name without parentheses. `Read(*)`, `Glob(*)`, `WebFetch(*)` are silently ignored and cause constant permission prompts. Edit/Write path patterns like `Edit(src/**)` and `Write(*.ts)` ARE valid because they match file paths.

### SSH commit signing is the default — verified signatures required
All commits must carry a verified signature (GitHub security protocol). Signing is SSH-based: `git config --global gpg.format ssh`, `user.signingkey ~/.ssh/<key>.pub`, `commit.gpgsign true`, `tag.gpgsign true`. `install.sh` (Phase 5.5) configures this per-machine, idempotently, and prints the key to register on GitHub as a **Signing Key** (Settings → SSH and GPG keys, type: Signing Key — or `gh ssh-key add <key> --type signing` after `gh auth refresh -s admin:ssh_signing_key`). For the "Verified" badge the committer email must be a verified account email (a `…@users.noreply.github.com` address qualifies). Never bypass with `--no-gpg-sign`; if signing fails, fix the key/agent. Merges via `gh pr merge` / the GitHub UI are signed by GitHub's web-flow key and show Verified automatically. A key with no passphrase (or one loaded into the macOS Keychain agent) is required so Claude Code's non-interactive commits don't hang.

### Lesson sync to the public repo is opt-in
<!-- shareable -->
Lesson sync between `~/.claude/rules/learned-patterns.md` (private, per-machine; Boris v3 moved lessons out of CLAUDE.md) and this public repo's `rules/learned-patterns.md` is **opt-in** in the Local→Repo direction: `sync-lessons.sh` promotes a lesson to the repo only if its block contains a `<!-- shareable -->` marker (placed on the line under its `### ` heading). Untagged lessons stay local, so private/org-specific notes never leak into the public repo. Repo→Local promotion is unchanged (shared lessons still flow to every machine) and dedup-by-heading is preserved. `install.sh` calls `sync-lessons.sh` and migrates lessons from pre-v3 CLAUDE.md files, so the installer is protected too. Guard tests: `./test-sync-lessons.sh`, `./scripts/test-install.sh`. This pattern is tagged as a live example of the marker.

### OpenAI/OpenRouter strict structured outputs reject schemas with OPTIONAL properties — require everything, use sentinels
<!-- shareable -->

`codex exec --output-schema` (OpenAI Responses strict mode) and OpenRouter `response_format: json_schema strict` both 400 (`param: text.format.schema`) on any object whose `properties` aren't ALL listed in `required` — a schema that works fine as a validation contract fails as a *generation* contract. The error surfaces as a backend-call failure that looks like a transport problem until you read the raw body. Fix: make every property required and define sentinels for not-applicable fields (`file: ""`, `line: 0`, empty strings, `[]`), documented next to the schema; your local validator then enforces required-all too. Sibling traps from the same session (claude-workflow multi-model build, 2026-07-19): codex refuses to run outside a trusted dir/git repo (`--skip-git-repo-check` + repo cwd), reads stdin when non-tty (feed the pack via stdin — argv has OS limits — or close it), and a reviewer given repo access will burn its budget exploring unless the prompt constrains it to targeted spot-checks. And schema `$comment` keys break closed-dialect validators — keep annotations out of wire schemas.
