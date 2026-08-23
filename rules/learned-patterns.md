# Learned Patterns

Ten rules that apply to **every** session regardless of stack. The other 96 lessons are
deferred at `~/.claude/lessons/learned-patterns.md` — **not auto-loaded**. Pull them when
the domain is in play:

```bash
~/.claude/scripts/memory-context.sh --grep 'nfs|systemd|rsync'   # scoped blocks
~/.claude/scripts/memory-context.sh --full                       # everything
```

The heading index at the bottom of this file is the map of what's in there. If a heading
looks like it might bear on the task, grep it before proceeding — that is cheaper than
rediscovering the lesson.

New lessons append to the deferred corpus. Promote one up here only if it applies
regardless of stack, fails **silently**, and you would not have known to go look.

---

## The hot core

### Write plainly — the contract lives in `rules/writing.md`
Sparse em-dashes, no corporate register, and direct data flow ("source: X → destination: Y",
never "copy from X to Y") are all rules in `~/.claude/rules/writing.md`, which also defines the
Brief block, the decision-brief form, and `## The chat stream`, which governs every answer
Claude writes in the running chat. Single source: read it there, not here. Justin has
corrected the em-dash, corporate-register, and data-flow habits by name, and named the two
that drove the chat rules: a coined name used in place of saying what is happening, and 30
words where 7 would do.

### Never re-propose an approach the record has ruled out
If `conventions.md`, a decision log, or a memory file documents an approach as infeasible
or rejected, do not suggest it again. Read the constraints at session start and respect
them. Re-proposing burns the user's time and defeats the entire point of persistent
memory.

### A negative claim is unverified until you re-run the search yourself
"X does not exist" is indistinguishable from a failed lookup — a blocked tool call, a
wrong path, a bad query form. A positive claim carries its evidence (the quoted line); a
negative one carries none. Subagents state absence as fact with confident wording; treat
every such report as a hypothesis and re-run it in the main context. Corollary: **a count
answered by grep is a lower bound, not a count.** If the number moves each time you look,
stop counting and write the enumerator — build it on the AST, not regex over source.

### Verify the RATIONALE separately from the verdict
When a task, ticket, or reviewer hands you a decision *and* the reason for it, those are
two claims. A right verdict with a false reason is worse than an open question: an open
question invites a fresh look, a recorded rationale gets relied on. Ship the verdict with
the *real* reason and record the refuted one under alternatives considered. Same shape for
compound claims ("A, B and C are all X, because Y") — verify each conjunct independently,
then re-derive the "because" against whatever survives.

### When a diagnosis goes sideways, stop and pull hard data
If a fix does not hold or evidence contradicts the theory, re-diagnose from logs, stored
metrics, or the live system instead of confidently floating the next guess. Confident-but-
wrong claims erode trust fast.

### Never-executed code has never been validated
A disabled variant, an unread local, a branch behind a flag nobody set: the obvious
one-line fix that makes it run is not low-risk, because nothing has ever exercised those
characters. Run the dead path before wiring it up — and check whether it should be enabled
at all, since "already disabled, already superseded, zero rows produced" usually means the
retirement decision was already made.

### Verify the ARTIFACT, not the success message
Installers, deploys, and backfills report success while shipping nothing: a version-stamp
gate skips a same-version content change, `fly secrets set` restarts without rebuilding, a
producer merges with tests and is never once run. After any install, deploy, or
remediation, grep the deployed artifact for a string that only exists in the new version,
or query the state the code was supposed to write. Merge status is not evidence.

### Background work is not done until the completion signal
A running Workflow or background task writes its journal incrementally, so a finder that
has not reported yet looks identical to one that returned nothing. Never conclude "clean"
from a partial read. Count started-vs-finished and treat any gap as still in flight.

### Map every location a config value appears before changing one
Config cascades: a settings class, function-parameter defaults, schema defaults, docs,
`.env.example`. Updating one layer leaves shadowed defaults that pass tests and diverge
from production. Grep the literal value across the whole codebase before changing any of
it.

### `~/Documents` is iCloud-synced — check for `" 2.<ext>"` before every commit
A `git mv` or rapid rename can race the sync daemon into leaving a `<name> 2.<ext>`
duplicate, and `git add -A` sweeps it into the commit — git's rename detection can even
record the junk file as the intended rename. After any rename in a `~/Documents` repo, run
`git status --porcelain` and grep for `" 2."`. Prefer explicit `git add <paths>` over `-A`
there.

---

## Deferred corpus — heading index

Retrieve with `memory-context.sh --grep '<keyword>'`. Full text:
`/Users/justinkeene/.claude/lessons/learned-patterns.md`.

**Reasoning & epistemics**
- Em-dashes are an LLM writing tell
- Never re-propose approaches that have been ruled out
- Don't say "decisive"; write plainly, not in corporate/LLM-speak
- When a diagnosis goes sideways, STOP and verify with hard data — don't re-assert
- A permission-blocked subagent reports ABSENCE as verified fact — treat every negative claim...
- When a count is wrong twice, stop counting and commit the counter
- A partly-wrong compound claim has THREE failure modes — the shared "because" is the one tha...
- When a task hands you a decision AND its rationale, verify the rationale separately — a rig...
- A file count is not a content claim, and a matching signature means read the owning issue first

**Process, docs & delivery**
- Always commit source files at phase boundaries
- Use subagents for Linear/project-management updates
- Phase completion checklist
- Check for user edits before regenerating output files
- Always update handoff + lessons at phase boundaries
- Separate products need separate repos from day one
- Always update README when pushing to main
- Linear issue audits must include ALL statuses, not just active
- Be precise about data flow direction
- Verify storage layout before destructive operations — never trust cached notes
- Config files must be loaded by the code that creates work items
- Always commit AND PUSH source files at phase boundaries
- Update README on session-end, not just Memory Bank
- Config defaults cascade — changing one layer isn't enough
- Replicate-from-API beats direct DB sharing for cross-app data flow
- Sequential PRs that touch the same docs will conflict — branch off latest main, expect a re...
- Version-stamp-gated installers silently stop shipping same-version content updates — verify...
- Additive lint/schema requirements must gate at the TEMPLATE, not the linter — or you retroa...
- An id-based validator cannot catch path rot — pair identity validation with path resolution
- Deleting an asset orphans STRING references that an import-graph grep will not surface
- CLI examples rot, and a script's own DOCSTRING is the propagation vector
- Never-executed code has never been validated — run the dead path before wiring it up
- A stale `task-context.md` on the default branch poisons foreign review, because it IS the eva...
- A shipped-but-never-run producer is indistinguishable from one that was never written

**Claude Code harness & agent infrastructure**
- An always-on instruction file is a context tax — measure it before adding to it
- Lesson sync to the public repo is opt-in
- Don't declare a Workflow adversarial review "clean" from a partial journal read — wait for ...
- A backgrounded process gets /dev/null on stdin — piping into a watchdog wrapper silently de...
- Scaffolding generators install auto-executing hooks — never commit an agent-config surface ...
- A gate whose evidence is an append-only log must anchor on SUCCESS, not on the last attempt
- A test fixture git repo with NO initial commit silently ignores `git checkout`
- A hook must emit at most ONE decision — two JSON objects is fail-open, not double-safe
- A review pack that WITHHOLDS files must declare the withholding, or reviewers report the gap ...
- Claude Code hooks: `permissionDecision: "ask"` is DISCARDED on tools that require user intera...

**Databases & datastores**
- better-sqlite3 + parallel `next build` → set `busy_timeout` BEFORE `journal_mode=WAL`
- Verify DB column names before writing queries
- Validate computed values on a small sample before large backfills
- `ORDER BY date DESC LIMIT 1` needs a tiebreak column — ties return ARBITRARY rows
- Idempotent SQL migrations: declared ≠ live — a constraint inside CREATE TABLE IF NOT EXIS...
- A retired datastore that still OPENS makes every stale reader a silent-wrong-answer generator
- A retired datastore that still exists on disk turns a dead script into a SILENTLY WRONG one
- A tripwire keyed on a different field than the writer sets can never fire
- A queued `DROP TABLE` head-of-line blocks the table its FK points at
- Archiving destroys any staleness check keyed on mtime — record the freeze date as data
- A migration whose PRECONDITIONS assert the start state cannot also be idempotent
- A "don't know" value reads as "fine", so pair it with a layer that cannot abstain

**Infrastructure & ops**
- Google Drive paths are too slow for Docker builds
- Don't kill processes by port when tunnels share that port
- Prefer rsync over SSH instead of rsync over CIFS/SMB mounts
- Always test cron commands manually before deploying
- `fly secrets set` does NOT rebuild the image
- `fly ssh console -C 'printenv X'` returns exit 1 with empty stdout if X isn't set
- crontab installers that do `crontab -l | grep -v | crontab -` under set -e silently no-op on ...
- NFS `nconnect` can't change while ANY mount namespace still holds the old superblock
- Deploy scripts that rsync a dir holding runtime .env + --delete will clobber the env AND dest...
- Docker's embedded DNS bypasses systemd-resolved — containers can't resolve MagicDNS/split-D...
- systemd keys in the wrong section are SILENTLY ignored — and the automount/mount failed-lat...
- `ssh host VAR="a b c" cmd` re-splits on the remote — quote env assignments with printf %q
- 25GbE-over-DAC that trains at 10G: the tell is Active FEC = None — pin RS and VERIFY, at de...
- Concurrent runs sharing a hardcoded remote staging path corrupt each other silently
- A path named for fast local storage can be a symlink onto a network mount — `readlink -f` t...
- An "append-only sync" can contain one non-append-only invocation, and "it no-ops here" needs ...

**Build, language & tooling**
- For non-trivial Node scripts, write to a temp file instead of `-e`
- Keep slash command `!` backtick commands simple — no redirects, pipes, or quoted strings
- multiprocessing.Pool.imap_unordered needs chunksize for large workloads
- Claude Code permission wildcard `(*)` only works for Bash
- Ruff has TWO CI gates — `check` AND `format --check`
- Use subagents for multi-file lint cleanup
- Python 3.11+ uses StrEnum, not `class Foo(str, Enum)`
- Pydantic validation raises ValueError, not generic Exception
- Verify a tool's REAL CLI before building a workflow on its docs
- Markdown section splitters (awk/grep on `^# `) must be code-fence-aware
- pnpm audit remediation: one range-override per package, bound every override target, prefer `...
- OpenAI/OpenRouter strict structured outputs reject schemas with OPTIONAL properties — requi...
- Unquoted `$VAR` in a `for` loop pathname-expands the PATTERNS themselves

**Frontend & web**
- Next.js server actions must self-authorize — middleware path gates are NOT enough
- Client edit forms must diff against a snapshot captured on open — never the live prop (rout...
- `<input type=date>` values are UTC-midnight — format AND compare in UTC, not local
- Derived CSS custom properties FREEZE at declaration scope — re-declare them in every theme ...
- Plain-CSS recipe classes vs Tailwind utilities: import ORDER decides ties — and SCSS-module...

**ML & evaluation**
- Validate threshold changes against real data before shipping
- Guided-JSON / structured-output schemas MUST bound every array (maxItems) and avoid free-text...
- A trained model's env fingerprint may describe the TRAINING box, not the feature extraction
- A throughput benchmark that ignores the success count is measuring failure rate
- An any-of-N rule measured on a single-class set inflates by construction

**Machine-local gotchas**
- Snapshot-then-drain send/job queues need FOUR guards, not just the snapshot
- Always check SDK type signatures, not just API docs
- iCloud-synced repos (~/Documents on macOS) spawn " 2.md" duplicates that git add -A sweeps in...
