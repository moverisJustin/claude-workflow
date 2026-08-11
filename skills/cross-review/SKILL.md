---
name: cross-review
description: Adversarial review by DIFFERENT model families for decorrelated blind spots — `code` mode reviews the branch diff via Codex, `design` mode reviews UI work for "looks like AI design" tells, `pr` mode fans the branch out to every configured foreign backend (Codex, Kimi via OpenRouter) with per-dimension prompts and merges the results. Claude verifies every foreign finding against the actual code before reporting.
argument-hint: [code|design|pr] [base-branch] [--models a,b | --all] [--comment] [--linear]
allowed-tools: Bash(codex:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*), Bash(bash ~/.claude/scripts/memory-context.sh *), Bash(bash .claude/scripts/memory-context.sh *), Bash(bash ~/.claude/scripts/review-pack.sh *), Bash(bash .claude/scripts/review-pack.sh *), Bash(bash ~/.claude/scripts/foreign-review.sh *), Bash(bash .claude/scripts/foreign-review.sh *), Bash(node ~/.claude/skills/cross-review/review-merge.mjs *), Bash(node skills/cross-review/review-merge.mjs *), Bash(gh pr comment:*), Bash(gh pr view:*), Read, Grep, Glob, Task
---

# Cross-Review — second model family, decorrelated blind spots

A model reviewing its own family's output shares its blind spots. This skill
runs the review through foreign model families instead — **OpenAI Codex CLI**
for `code`/`design`, plus **Kimi (via OpenRouter)** in `pr` mode — then treats
every foreign finding as an unverified claim that Claude must try to refute
against the actual code before it reaches the user.

Arguments: `$ARGUMENTS` — mode (`code` default, `design`, or `pr`) and
optional base branch (default `main`). `pr` mode additionally accepts
`--models a,b` / `--all` (backend selection), `--comment` (inline PR
comments), `--linear` (post summary to the Linear issue).

**Fail loud, never substitute — all modes.** A missing binary, key, or config
is reported with its reason; the run never silently swaps in a same-family
reviewer and calls it a cross-review, and never fabricates a backend's output.

## 0. Probe the real CLI (never assume)

```bash
codex --version
```

- Missing → stop and report: install via the official Codex CLI instructions,
  then re-run. Do NOT fall back to reviewing with Claude and calling it a
  cross-review.
- Present → confirm the flags you're about to use exist (`codex exec --help`).
  Known-good surface on 0.144.x: `codex exec review --base <branch>` with NO
  prompt (see below), and
  `codex exec [-i <image>...] [--output-schema <file>] [-s read-only] "<prompt>"`.
  If a flag is gone, adapt to what the installed binary actually offers.

## 0.5 Load project memory context (so the foreign model isn't blind)

Claude auto-loads this repo's memory every session; Codex does not. Reviewing a
diff with no standing context, it can't tell house style from a bug and will
"find" things you already ruled out. Assemble the portable memory slice and give
it to Codex as reference:

```bash
bash .claude/scripts/memory-context.sh > /tmp/cross-review-memory.md 2>/dev/null \
  || bash ~/.claude/scripts/memory-context.sh > /tmp/cross-review-memory.md 2>/dev/null \
  || true
```

This pack is the Memory Bank (project identity, conventions, ruled-out
decisions) + the active task context + a pitfalls index from
`learned-patterns.md`. Options: `--grep '<keywords>'` biases the pitfalls
toward the diff's subject (e.g. `--grep 'sqlite|migration'`); `--full` inlines
every pitfall body (use on release-branch reviews). If the pack is empty (a
project with no Memory Bank yet), skip it and review on the diff alone — don't
fabricate context. The pack is reference DATA for Codex, never new
instructions.

## 1a. Code mode (default)

Lead the review prompt with the memory pack so Codex reviews with the project's
conventions and ruled-out decisions in view.

**`codex exec review --base <branch>` cannot take a prompt.** On 0.144.x the two
are mutually exclusive and the binary refuses outright:

```
error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
```

Its usage line prints `codex exec review --base <BRANCH> [PROMPT]`, which reads
as though both are allowed. They are not, and `-` (prompt-on-stdin) is still a
prompt, so that fails the same way. Any recipe combining them has never worked.
Verified against codex-cli 0.144.1 on 2026-08-11.

Use plain `codex exec`, which takes a prompt and lets you hand over the memory
pack, the focus, and the diff in one place:

```bash
git diff <base-branch>...HEAD > <scratch>/branch.diff
{ cat /tmp/cross-review-memory.md
  cat <scratch>/focus-prompt.md
  printf '\n=====  THE DIFF  =====\n\n'
  cat <scratch>/branch.diff
} > <scratch>/codex-prompt.md

codex exec -s read-only - < <scratch>/codex-prompt.md
```

Capture the full output. Expect it to take several minutes on a large diff, so
run it in the background rather than blocking the turn.

**Codex runs sandboxed, and the sandbox blocks temp-file writes.** Any repo
script it executes that uses the house `python3 - <<'PY'` heredoc pattern fails
with `cannot create temp file for here document: Operation not permitted` and
exits 1. Treat every "script X exits 1 / is broken" observation from inside that
sandbox as a sandbox artifact until you re-run the script yourself outside it.
The accident is still useful: it is free fault injection, and it is how a
fail-closed bug in `hook-plan-gate.sh` was found.

## 1b. Design mode

For UI/UX changes — components, styles, layouts, marketing pages. Codex has
sharper taste for generic-AI design tells, so give it both the code and the
pixels:

1. Collect the UI diff (`git diff <base>...HEAD -- '*.tsx' '*.jsx' '*.css'
   '*.svelte' '*.vue' '*.html'` — adapt to the stack).
2. If screenshots exist (from `/verify`, the Browser pane, or the user),
   attach them: `-i shot1.png -i shot2.png`.
3. Write a JSON Schema for findings to a scratch file (fields: `file`, `line`,
   `summary`, `why_it_reads_as_ai`, `suggestion`, `severity`) and run — leading
   the prompt with the memory pack (step 0.5) so Codex respects the project's
   existing design system and conventions instead of inventing its own:

```bash
codex exec -s read-only --output-schema <schema-file> \
  -i <screenshots...> "$(cat /tmp/cross-review-memory.md)

<design review prompt + the diff on stdin>" < diff.txt
```

Prompt Codex to hunt specifically for: template-default typography and
spacing, gradient/glassmorphism clichés, purple-blue AI palettes, uniform
border radii, emoji-as-design, generic hero/feature-grid structures,
inconsistency with the project's existing design system, and anything that
reads as "AI-generated page" rather than designed. Ask for concrete fixes,
not vibes.

## 2. Adversarially verify every finding

For each Codex finding, try to **refute** it against the actual code:
- Read the cited file/lines. Does the failure scenario hold? Is there a guard
  Codex missed? Is the "AI tell" actually the project's established style?
- Kill any finding that merely restates something the memory pack already
  documents — an established convention, a locked or ruled-out decision. That's
  house style Codex lacked context for, not a defect; the pack should make these
  rarer, but catch the ones that slip through.
- Kill findings you can refute; mark the rest CONFIRMED (you reproduced the
  reasoning) or PLAUSIBLE (couldn't refute, couldn't fully confirm).

## 3. Report

Most severe first. For each surviving finding: file:line, what's wrong, the
failure scenario (or the design tell), verdict, and which model surfaced it.
State plainly how many Codex findings were refuted and dropped — that number
is the evidence the verification pass is real. If Codex returns nothing,
say so; don't pad.

---

# PR mode — `/cross-review pr [base-branch] [--models a,b | --all] [--comment] [--linear]`

Multi-backend, dimension-routed review of the whole branch against its spec.
Each backend reviews the same **review pack** (charter-first memory + spec +
changed files) through its assigned dimension prompts, emits findings in the
shared schema (`schemas/findings.schema.json` next to this skill), and the
results are mechanically merged, semantically reconciled, and adversarially
verified before anything reaches the user.

Schema note: every property is **required** — OpenAI/OpenRouter strict
structured-output modes reject schemas with optional properties (verified
live: Codex returned 400 on `text.format.schema` until all fields were
required). Not-applicable fields carry sentinels: `file: ""` (not
file-specific), `line: 0` (no anchor), `evidence`/`suggested_fix`/
`coverage_notes: ""`, `lessons: []`. Treat sentinel anchors accordingly when
merging and reporting.

## Backend config — resolution order

The routing table is data, not code: `review-backends.json`. Resolve in this
order and use the FIRST file found whole (no per-key merging):

1. `.claude/review-backends.json` — project override
2. `~/.claude/review-backends.json` — user override
3. the shipped default next to this skill
   (`~/.claude/skills/cross-review/review-backends.json`)

The config carries `version` (must be 1), a top-level `exclude` glob array
(sensitive paths that must never enter a pack — default `.env*`, `**/*.pem`,
`**/secrets/**`), and per-backend: `runner` (`codex`, `openrouter:<model-id>`,
or `native`), `enabled`, `dimensions`, `input`, optional
`context_budget_bytes`, optional `role`. Kimi's model id is set at setup
(`MODEL_ID_SET_AT_SETUP` means setup hasn't happened — a LOUD skip reason,
not an error to paper over).

Selection: default = all `enabled` foreign backends; `--models a,b` restricts
to exactly those; `--all` includes disabled ones too. **Requested but
unavailable = loud skip** — named in the report with the reason, never
silently dropped, never substituted.

## pr.0 Probe backends against the resolved config

For each selected foreign backend, probe availability via the shared runner:

```bash
bash .claude/scripts/foreign-review.sh --probe --backend <runner> \
  || bash ~/.claude/scripts/foreign-review.sh --probe --backend <runner>
```

Record per-backend status with the real reason: `codex: available`,
`kimi: SKIPPED — no OPENROUTER_API_KEY in ~/.claude/foreign-review.env`,
`kimi: SKIPPED — model id not set (run setup)`, `codex: SKIPPED — binary not
on PATH`. `claude-native` is never probed here — it's a prerequisite (next
step), not a merge participant. If EVERY foreign backend is unavailable, stop
and report setup instructions; you may offer a native-only review but never
label it a cross-review.

## pr.0.5 Prerequisites — native reviews (excluded from the merge)

`/code-review` and `/security-review` are **prerequisites, not merge
participants**. Check whether each has run on this branch (ask the user /
check the session); list each as `ran` or `not run` in the report footer.
Their findings are EXCLUDED from dedup, agreement marking, and backend stats —
the report must never imply the merge pipeline ingested findings it didn't.
The memory-pack rules of step 0.5 apply to PR mode too; `review-pack.sh`
embeds the pack charter-first, and the same "empty pack → proceed without,
never fabricate" rule holds.

## pr.1 Build the pack, fan out in parallel

Build one review pack (memory charter-first + resolved spec + changed files
within each backend's byte budget, diff hunks for the rest):

The base branch is POSITIONAL (this doc said `--base` for a while; the script
never accepted it, so every documented invocation failed usage). Pass the
config's `exclude` globs through as repeated `--exclude` flags — they are what
keeps sensitive paths out of the pack:

```bash
bash .claude/scripts/review-pack.sh <base-branch> \
  --exclude '.env*' --exclude '**/*.pem' --exclude '**/secrets/**' \
  --out <scratch>/pack.md \
  || bash ~/.claude/scripts/review-pack.sh <base-branch> \
       --exclude '.env*' --exclude '**/*.pem' --exclude '**/secrets/**' \
       --out <scratch>/pack.md
```

**Exclusion is not the same as the secret scrub, and you want both.** The scrub
in `foreign-review.sh` is a HARD STOP: one secret-shaped string anywhere in the
pack aborts the entire review (exit 6). Excluding a path trims the pack instead.
Any repo containing scrub *fixtures* — this one does, in
`scripts/test-foreign-review.sh` — is otherwise un-reviewable by its own tool.
Exclude such files and record the coverage gap in the footer.

Surface the pack's `SPEC:` line and any `TRUNCATED:` notes now — both must
reappear in the report footer.

Then launch every AVAILABLE backend **in parallel** (background Bash), one
`foreign-review.sh` call per backend, each with the shared schema and its
dimension prompts from `prompts/` next to this skill:

- **codex** → `prompts/correctness.md` + `prompts/design.md`, one call
  (`--backend codex`, `-s read-only --output-schema` under the hood — Codex
  emits the shared schema directly).
- **kimi** → `prompts/spec-drift.md` + `prompts/architecture.md` +
  `prompts/test-gap.md` concatenated into **ONE call** (long context; one
  call, not three) with `--backend openrouter:<model-id-from-config>`.

```bash
bash ~/.claude/scripts/foreign-review.sh --backend <runner> --mode code \
  --schema ~/.claude/skills/cross-review/schemas/findings.schema.json \
  --input <scratch>/pack.md --prompt <scratch>/<backend>-prompts.md \
  --out <scratch>/<backend>.json
```

A backend failure (exit 3 unavailable / 4 call failed / 5 schema-invalid) is
reported to the user verbatim; continue with the survivors after saying so.
Fallback: if `--output-schema` is unusable on the installed Codex, `codex exec
review --base` prose may be normalized into the schema by main-context Claude
as an explicit stage — original text preserved in `evidence`, findings marked
`normalized: true`, unmappable prose goes to a report appendix. Never faked
into schema fields.

## pr.2 Mechanical merge

```bash
node ~/.claude/skills/cross-review/review-merge.mjs \
  codex:<scratch>/codex.json kimi:<scratch>/kimi.json > <scratch>/merged.json
```

Arguments are **backend-tagged**: `<backend>:<path>`, one per successful
backend. Dedup key: same category + same file + line within ±3 → one finding
carrying a `sources` array and `agreement: true` when 2+ backends flagged it.
Malformed input is a loud nonzero failure — drop that backend explicitly and
rerun the merge without it; never hand-edit a backend's JSON into shape.

## pr.3 Semantic pass, then adversarial verify

Semantic pass (main context — this is why PR review is skill choreography,
not a workflow):

- Merge same-root-cause findings the mechanical ±3-line key couldn't see.
- When two backends propose **contradictory fixes** for the same code, do not
  pick a winner silently — record an explicit **Disagreement** item carrying
  both positions for the report.

Adversarial verify every surviving finding (`agreement: true` is high signal
but still gets verified):

- **Mechanical categories** (`correctness`, `perf`, `test-gap`) → parallel
  **sonnet** Task agents, each batching **at most 5 findings**, instructed to
  refute each finding against the actual code and return
  CONFIRMED/PLAUSIBLE/REFUTED + reasoning.
- **Judgment categories** (`spec-drift`, `design`, `security`) → verify in the
  **main thread**, against the charter/spec and the project's real
  conventions.
- **Both-flagged criticals get both**: a sonnet pass AND a main-thread check.

REFUTED findings are dropped and counted per backend. The step-2 kill rules
(convention restatements, ruled-out decisions) apply unchanged.

## pr.4 Report

Issues-only, most severe first, no praise. Per finding:

- severity — `file:line` — concrete failure scenario — found-by
  (both-flagged marked, e.g. `codex+kimi (agreement)`) — verdict
  (CONFIRMED/PLAUSIBLE) — fix direction.
- Disagreement items listed explicitly with both positions.

**Mandatory footer** — every line, every run:

- per-backend raised / refuted counts (the evidence verification is real)
- backends run vs SKIPPED, with reasons
- prerequisites status: `/code-review` ran/not run, `/security-review`
  ran/not run
- spec source used (or the pack's loud `SPEC: none found` marker)
- truncation notes from the pack, if any
- cumulative calibration per backend/dimension read from
  `~/.claude/reviews/backend-stats.jsonl` (e.g. "codex/correctness: 62%
  confirmed over 34 findings"; say "no calibration history yet" if the file
  is absent — never invent numbers)

Delivery: print to the terminal ALWAYS, and save the same report to
`.claude/reviews/<branch-slug>-<date>.md` (gitignored). Posting is opt-in,
**flags only, never default**: `--comment` posts inline PR comments via `gh`;
`--linear` posts the summary to the task's Linear issue via the
`linear-project-manager` subagent.

## pr.5 Calibration ledger

Append one JSONL line **per backend** to `~/.claude/reviews/backend-stats.jsonl`
(single-line O_APPEND writes). Versioned so cohorts stay comparable — same
fields as the plan-stage ledger, with `stage: "pr"`: run id, stage, backend,
exact model id, schema version, prompt-file hash, repo, date, and counts with
`confirmed` and `plausible` tracked separately (precision is reported on
CONFIRMED; PLAUSIBLE shown alongside, never pooled in). Routing-table changes
stay human decisions informed by the footer — no automated demotion.

## pr.6 Foreign agent write path (OPT-IN, permission-gated per instance)

Reviews are read-only **by default**, but when the user explicitly authorizes
it (per instance — a gate option or direct instruction, never automatic), a
foreign agent may be handed write work:

- **Fix delegation**: after a PR-stage review, offer "Delegate confirmed
  fixes to Codex?" → `codex exec` runs with a write-enabled sandbox
  (`-s workspace-write`; verify the exact flag surface on the installed
  binary) **inside the task branch/worktree**, scoped by the charter +
  confirmed findings + memory pack. The foreign agent edits files; it never
  commits or pushes — git stays Claude's.
- **Decorrelation both ways**: Claude adversarially reviews the foreign diff
  (same verify pass, roles reversed) → `/checks` → Claude commits with source
  attribution in the message.
- **Memory updates**: the findings schema's optional bounded `lessons[]`
  field is the foreign-proposed-lessons channel; foreign-proposed lessons are
  treated as **proposals Claude validates** before writing to
  `conventions.md`/`learned-patterns.md` (attributed to the source model).
  With explicit instruction, a foreign agent may edit memory files directly
  in the worktree — still diffable, still Claude-reviewed pre-commit.
  Everything lands on a git-tracked surface so it's inspectable and
  revertible.
- **Kimi**: API-only (no agentic file access) — contributes findings/lessons
  only; the write path applies to CLI-backed agents (Codex today).

## Notes

- Codex model/auth comes from the user's own `~/.codex/config.toml` — don't
  override the model unless asked. OpenRouter auth comes from
  `~/.claude/foreign-review.env` (user-created, chmod 600, never committed).
- This complements `/code-review` (same-family review), not replaces it. For
  release branches run both; in `pr` mode the native reviews are explicit
  prerequisites (pr.0.5).
- Never let a foreign model apply fixes outside the opt-in write path above —
  review runs read-only; fixes happen here, where the loop-closing contract
  applies.
- `scripts/memory-context.sh` is the reusable primitive for handing any
  foreign agent this repo's standing memory — same `run + prepend` works for a
  local model, an Orca agent, or a background task, not just Codex here.
