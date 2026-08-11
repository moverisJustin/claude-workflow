---
id: arc-multi-model-orchestration-v1
title: Multi-Model Orchestration (Task Charter, Plan Gate, PR Review Fan-Out)
type: ARC
status: Accepted
version: 1.0.0
owner: Justin Keene
domain: engineering-workflow
created: 2026-07-19
updated: 2026-07-19
related:
  - dec-documentation-channels-001
---

# Multi-Model Orchestration (Task Charter, Plan Gate, PR Review Fan-Out)

## Brief
**What this is.** A record of how Claude hands work to rival model families for review, and what blocks a plan at approval.
**Why.** One model reviewing its own work shares its own blind spots. A second family sees what the first cannot.
**What changes.**
- Claude plans and orchestrates. Codex and Kimi only review; they never write.
- Review runs at two points: before you approve a plan, and before a PR opens.
- Claude checks every foreign finding against the code before you read it.
- Claude reports a missing backend, and never quietly stands in for it.
- The task charter is the frame every reviewer judges the work against.

**What you must decide.** Nothing. This records a decision already taken.
**Risk.** A foreign reviewer sees no project context, so it reports things you ruled out long ago. The memory pack exists to prevent that.

## Overview

Architecture record for evolving the Boris workflow into a multi-model
orchestration: **Claude remains the orchestrator and planner**, and foreign
model families (OpenAI Codex CLI; Kimi via OpenRouter) provide decorrelated
adversarial review at two boundaries — **plan-stage** (human-gated,
complexity-triggered) and **PR-stage** (optional, strength-routed). Every
reviewer, native or foreign, judges against one central source of truth for
the task's goals: the **Task Charter**. Memory flows to and from foreign
models through the existing context-pack primitive, and sub-agent work is
right-sized by model tier.

Everything extends existing primitives (`memory-context.sh`, `/cross-review`,
`/boris`, the Loops ledger); nothing is a parallel system. This is a
reference document: the what/why and the contracts. Implementation details
live in the scripts and skills themselves.

## Context

Codex, running separately, found a large number of real issues in the
Claude-built Mira finance sub-app that Claude's own review had missed —
direct evidence that **same-family review inherits the biases that created
the bugs**. A model reviewing code produced by its own family shares the
blind spots that let the defects through in the first place.

The decorrelation rationale: a reviewer from a different model family, with a
different training distribution, flags a partially disjoint set of problems.
The value is not that the foreign model is better — it is that its errors are
decorrelated from ours. Claude adversarially verifies every foreign finding
against the actual code before it reaches a report, so foreign noise is
filtered while foreign signal survives.

Design constraints that shaped the architecture:

- **One source of truth for goals.** Reviewers disagreeing about what the
  task even is produces noise; the Task Charter gives every reviewer the same
  evaluation frame.
- **Human gates, not automation.** The plan gate fires only when complexity
  warrants and is always approved by Justin; PR review posting to PR/Linear
  sits behind explicit flags; routing-table changes stay human decisions.
- **Fail loud, never fabricate, never substitute.** A missing backend, key,
  or spec is reported verbatim — never silently dropped or faked.
- **Extend, don't fork.** Charter = tightened contract on the existing
  `.claude/task-context.md`; PR review extends `/cross-review`; packs come
  from `memory-context.sh`.

## Architecture

```
                    ┌── Task Charter (task-context.md: Objective / Non-goals / Acceptance)
                    │      = source of truth; memory-context.sh emits it FIRST in every pack
                    ▼
 PLAN ──/anythingelse──► complexity bar? ──AskUserQuestion gate──► foreign-review.sh
                                                                    ├─ codex (exec -s read-only, --output-schema)
                                                                    └─ openrouter:<kimi> (curl + json_schema)
                                              reconcile (verify → fold in → disagreements table)
                                              ▼
                              ExitPlanMode: ONE approval of the reconciled plan
                                              ▼
 BUILD (boris steps 0–4, right-sized delegation per policy table)
                                              ▼
 /task-done ──external-review gate──► /cross-review pr  (routing table: codex=correctness+design,
                                       kimi=spec-drift+architecture+test-gap, native=baseline+security)
                                              ▼
                    merge → dedup → adversarial verify → issues-only report → Justin
                                              ▼
              write-back: Decisions rows, conventions.md, learned-patterns.md, calibration ledger
```

## Component 1 — Task Charter (source of truth)

A tightened contract on the existing `.claude/task-context.md` — no new file.
Three sections: `## Objective` (what + why), `## Non-goals` (scope fence),
`## Acceptance` (checkable criteria). Kept cheap: one line per item is fine;
placeholders are never left in place.

**Precedence.** The charter owns goals and scope. The BSpec doc (pointed to
by the ledger's `**BSpec**:` line) owns durable design detail. Linear mirrors
the charter, one-way charter→Linear after the initial link.

**Acceptance/waiver syntax** — defined, not free-form; the task-done gate
greps exactly these forms:

| Form | Meaning |
|---|---|
| `- [ ] <criterion>` | open |
| `- [x] <criterion>` | done |
| `- [~] waived: <reason>` | waived, with a mandatory reason |

`/task-done` must not report complete while any Acceptance item is unchecked
and unwaived. Stable per-item IDs were considered and rejected as
over-engineering at this scale.

**Charter-first packs.** `memory-context.sh` extracts the charter sections
plus the BSpec ledger line (fence-aware awk) and emits them as the pack's
first section, `## Task charter (evaluation frame)` — unconditional whenever
a charter exists. Every pack consumer (cross-review, prime-agent,
plan-review, PR packs) inherits the evaluation frame for free. When no
charter exists, packs are unchanged (legacy behavior).

**Drift posture.** `drift-check.sh` WARNs (never ERRORs) on missing charter
headings or untouched placeholders — backfill-friendly by design.

## Component 2 — `foreign-review.sh` (shared runner)

The single backend-agnostic entry point for calling a foreign model (bash
3.2 + curl + jq):

```
foreign-review.sh --backend codex|openrouter:<model> --mode plan|code
                  --schema FILE --input FILE [--out FILE] [--prompt FILE]
                  [--timeout SECS] [--probe] [--quiet]
```

**Backends.**

- `codex`: `codex exec -s read-only --skip-git-repo-check --output-schema
  "$SCHEMA"`, with cwd set to the repo root and the pack fed via stdin (never
  argv — OS argument limits), stdin-consumption handled. All three
  requirements were verified in the live dogfood run.
- `openrouter:<model>`: `curl POST` with `response_format: json_schema`
  (strict), temperature 0.2, jq-built body. Model ids live in the routing
  config, not the env file (ids drift; resolve at setup time).

**Exit-code contract** (fail loud, never fabricate, never substitute):

| Exit | Meaning |
|---|---|
| 0 | valid, schema-conformant review produced |
| 2 | usage error |
| 3 | backend unavailable (binary/key missing) |
| 4 | call failed (after one automatic retry on transport-class failures) |
| 5 | backend returned schema-invalid output |

Raw output is always preserved at `<out>.raw`; `--out` is written only on
success. A transport failure (stream disconnect mid-run — observed live)
gets exactly one automatic retry, then a loud exit 4.

**Security measures.**

- **Endpoint allowlist**: the API key is only ever attached to the pinned
  OpenRouter URL; any `FOREIGN_REVIEW_ENDPOINT` override outside the
  allowlist refuses to attach the key.
- **Payload preflight + scrub**: before any third-party send, the gate shows
  provider, endpoint, byte size, and included sections/paths; a
  secret-pattern scrub (key-shaped strings, `.env`-style lines) runs over the
  pack and hard-stops on hits; `review-backends.json` supports an `exclude`
  glob list for sensitive paths. A full data-classification policy is
  deferred beyond v1.
- **Secrets**: `~/.claude/foreign-review.env` (chmod 600, user-created, never
  committed or deployed by install.sh — settings.json was rejected because
  install.sh Phase 5 would wipe it). Contains only `OPENROUTER_API_KEY`.
- **Schema validation is a real validator, not jq**:
  `scripts/validate-findings.mjs` (Node, zero deps) implements exactly the
  restricted JSON-Schema dialect both findings schemas use — `type`
  object/array/string/integer, `required`, `properties`, `enum`, `maxItems`,
  `maxLength`, `additionalProperties:false`. We own both schemas, so the
  dialect is closed by construction.
- **Portable timeout**: macOS ships no `timeout(1)` — a watchdog subshell
  with process-group TERM→KILL and `trap` cleanup of partial raw files.

**Test seams**: `CODEX_BIN`, `CURL_CMD`, `FOREIGN_REVIEW_ENDPOINT`,
`FOREIGN_REVIEW_ENV_FILE`, mirroring `memory-context.sh` conventions; the
offline suite (`test-foreign-review.sh`) stubs both backends and covers every
exit code, never-write-on-failure, hanging and TERM-ignoring backends, the
secret-scrub hard stop, and the endpoint-allowlist refusal.

## Component 3 — Plan-stage review gate (`/plan-review`)

Runs **inside plan mode**, after the `/anythingelse` checkpoint and before
ExitPlanMode. Both backends are repo-side-effect-free (`-s read-only` / pure
API call), the plan file is the one editable surface, and Justin approves
**once**, seeing the reconciled plan.

**Complexity bar.** The gate is auto-offered only when the plan is
multi-module, makes architectural decisions, or touches
financial/data-integrity/security surface. Below the bar: record
`External review: skipped — below complexity bar` in task-context and
proceed. `/plan-review` is manually invocable at any time.

**Flow.**

1. Probe both backends (`--probe`).
2. AskUserQuestion gate showing real availability ("Kimi unavailable: no
   key" is stated, never silently dropped) plus the payload preflight (what
   is being sent, where, how big).
3. Assemble the plan pack in scratch: a `# Plan Review Request` header with
   injection-boundary framing and an **exploration constraint** ("review the
   plan document; targeted spot-checks only" — without it a repo-access
   reviewer burns its budget roaming, observed in the dogfood), the
   charter-first memory pack, and the verbatim plan file.
4. Fan out both backends in parallel; collect; fail loud (a backend failure
   is reported verbatim; ask continue-with-survivor or abort).
5. **Adversarial verify** each finding against the plan and the actual repo;
   convention-restatements are killed.
6. **Reconcile into the plan file**: accepted changes folded in with
   `[ext-review <backend>:<id>]` attribution, plus an appended
   `## External review outcome` section (counts table, refuted findings with
   reasons).

**Disagreement resolution — a gate, not just a table.** Every material
reviewer disagreement (or reviewer-vs-Claude conflict) becomes one
AskUserQuestion — position A / position B / defer with an explicit blocking
condition — and the operative plan is rewritten to a single executable
decision **before** ExitPlanMode. An approved plan never contains
contradictory implementation choices; the outcome table records who held what
and what was chosen.

**Charter sync at reconciliation, not session-end.** Accepted findings are
classified for charter impact (goal/scope/acceptance changes). Charter deltas
are written into the plan as an explicit "Charter updates" subsection so the
single approval covers them (plan mode cannot edit task-context), then
applied to task-context + Decisions + the Linear mirror as the **first
post-approval act** — Boris and PR review never run against a stale charter.

**Findings schema** (bounded per the guided-JSON learned pattern): verdict
enum `approve|approve_with_changes|revise`; findings `maxItems` 12; severity
`blocker|major|minor|question`; area enum; `maxLength` on every string;
`additionalProperties: false`.

**Post-approval:** raw JSONs copied to `.claude/reviews/` (gitignored), one
outcome line in task-context, and the outcome table carried into the BSpec
doc when authored.

## Component 4 — PR-stage multi-model review (`/cross-review pr`)

Extends the existing `/cross-review` skill (name and muscle-memory kept;
`code`/`design` modes unchanged; Codex-only degradation stays loud). Skill
choreography, not a Workflow: 2–3 backend calls need no workflow plumbing,
and reconciliation benefits from the main conversation's mental model of the
branch.

**Routing table as data.** `skills/cross-review/review-backends.json`,
resolved project `.claude/` → user `~/.claude/` → shipped default; dimension
prompts are editable files in `skills/cross-review/prompts/`; `--models a,b`
/ `--all` override per run.

| Backend | Dimensions | Rationale |
|---|---|---|
| codex | correctness, design | proven strength (Mira incident); emits the shared findings schema directly via `--output-schema` |
| kimi (OpenRouter) | spec-drift, architecture, test-gap | long context: one call carries all three dimension prompts |
| native Claude (`/code-review`, `/security-review`) | baseline, security | **prerequisites, not merge participants** |

Native reviews run before the external pass and are listed in the report
footer as prerequisites (ran / not run). They are excluded from dedup,
agreement marking, and backend stats — the report never implies the merge
pipeline ingested findings it didn't. Codex's purpose-built
`exec review --base` remains an optional fallback whose prose is normalized
by main-context Claude as a specified stage: original text preserved in
`evidence`, findings marked `normalized:true`, unmappable prose goes to a
report appendix — never faked into schema fields.

**Review pack** (`scripts/review-pack.sh`): charter-first memory pack + spec
resolution (argument → ledger BSpec path → task-context Plan → loud
`SPEC: none found` marker that must surface in the report) + changed files
inlined up to the per-backend `context_budget_bytes` (bytes as the honest
proxy unit, headroom reserved for model output). Diff hunks are included only
for files not already inlined in full — no unconditional duplication.
Overflow produces a loud `TRUNCATED:` note.

**Findings schema** (`skills/cross-review/schemas/findings.schema.json`):
same conventions as the plan schema — bounded; severity
`critical|high|medium|low`; category
`correctness|security|spec-drift|design|perf|test-gap`; `file:line` anchors;
`failure_scenario` required.

**Merge → verify pipeline.**

1. Mechanical merge (`skills/cross-review/review-merge.mjs`, Node): dedup on
   file + line±3 + category; `sources[]` recorded; `agreement:true` when 2+
   backends flag the same thing (high signal, still verified).
2. Claude semantic pass: merge same-root-cause findings; contradictory fixes
   become explicit Disagreement items.
3. Adversarial verify: every finding ends CONFIRMED, PLAUSIBLE, or
   REFUTED-and-dropped. Verification is right-sized: mechanical categories
   (correctness/perf/test-gap) go to parallel sonnet subagents batching ≤5
   findings; judgment categories (spec-drift/design/security) stay in the
   main thread.

**Report contract** (issues-only, most-severe-first, no praise):

- Per finding: severity, `file:line`, concrete failure scenario, found-by
  (with both-flagged marker), verdict, fix direction.
- Mandatory footer: per-backend raised/refuted counts, backends run vs
  SKIPPED with reasons, spec source used, truncation notes, cumulative
  calibration precision (Component 5).
- Delivery: terminal always + saved `.claude/reviews/<branch>-<date>.md`
  (gitignored). `--comment` (inline PR comments via gh) and `--linear`
  (haiku linear-project-manager) are explicit flags only — never default.

**Gate.** `/task-done` step 2.7 (after `/checks` green, before the PR):
AskUserQuestion "External PR review? [All backends / Codex only / Skip]".
Confirmed critical/high findings → fix-now (re-run `/checks`) or
ship-with-known-issues (PR body `## Known Issues (external review)` block).
The PR body gains one `## External Review` summary line, which survives
task-context deletion at merge.

**Foreign agent write path (opt-in, permission-gated per instance).** Reviews
are read-only by default. When Justin explicitly authorizes it — per
instance, never automatic — a foreign agent may be handed write work: `codex
exec` with a write-enabled sandbox inside the task branch/worktree, scoped by
the charter + confirmed findings + memory pack. The foreign agent edits
files; it never commits or pushes — git stays Claude's. Decorrelation runs
both ways: Claude adversarially reviews the foreign diff, runs `/checks`,
and commits with source attribution. Writes always land on a git-tracked
surface, so everything is inspectable and revertible. Kimi is API-only (no
agentic file access) and contributes findings/lessons only in v1.

## Component 5 — Policy: right-sizing, memory writes, calibration

**Right-sized delegation** (`rules/workflow.md`):

| Tier | Work |
|---|---|
| haiku | Linear ops, memory-bank curation, git mechanics |
| sonnet | BSpec drafting (main Claude validates), docs/retro, tests, implementers, boris-build gates/fixers |
| opus | design judgment, incident debugging |
| main context (reserved) | reconciling foreign findings, plan approval, all memory writes |

Rule of thumb: mechanical → haiku; structured authoring against a clear
brief → sonnet; judgment/reconciliation → opus/main. Doc/Linear ops are
single steps — a subagent, not a Workflow; parallel cheap agents only where
fan-out is real.

**Memory-write invariant — ONE rule:** *foreign models and subagents
PROPOSE; main-context Claude performs every persistent memory write.*
Proposals arrive as the bounded `lessons[]` schema field or, under the
opt-in write path, as worktree file edits that remain proposals until Claude
reviews and commits them (the audit trail is the git diff). The
`memory-bank` agent curates and audits structure, never authors content.
Plan/PR reconciliation writes adopted/rejected findings + rationale to
task-context `## Decisions`; validated cross-model convention gaps go to
`conventions.md`; universal lessons to `learned-patterns.md` at
`/session-end`. This invariant exists because the earlier draft contradicted
itself across phases — caught by the external review (MMO-010 below).

**Calibration ledger.** Reconciliation appends one JSONL line per run to
`~/.claude/reviews/backend-stats.jsonl`. Each event is versioned so cohorts
stay comparable:

```json
{"run_id": "...", "backend": "codex", "model_id": "gpt-5.6-sol",
 "schema_version": "...", "prompt_hash": "...", "repo": "...",
 "date": "YYYY-MM-DD", "raised": 0, "confirmed": 0, "plausible": 0,
 "refuted": 0}
```

CONFIRMED and PLAUSIBLE are tracked separately: precision is reported on
CONFIRMED only, with PLAUSIBLE shown alongside, never pooled in. Appends are
single-line O_APPEND writes (single-user machine). Every report footer shows
cumulative precision per backend/dimension (e.g. "codex/correctness: 62%
confirmed over 34 findings"). Routing-table changes stay **human decisions
informed by the footer** — no automated demotion until enough versioned data
exists.

## External review outcome (the source plan, dogfooded)

The plan behind this architecture was itself put through the process it
describes — evidence the process works. Reviewer: **codex (gpt-5.6-sol,
`exec -s read-only --output-schema`)**; verdict `revise`; **11 findings → 8
accepted, 3 partially accepted, 0 refuted**. Kimi: SKIPPED — no OpenRouter
key yet (the plan's own prerequisite).

| Finding | Area | Verdict | Action |
|---|---|---|---|
| MMO-001 payload sent to third party without disclosure/redaction | security | CONFIRMED (partial) | Preflight disclosure + secret scrub + endpoint allowlist + exclude globs; full data-classification policy deferred |
| MMO-002 jq is not a schema validator | correctness | CONFIRMED | `validate-findings.mjs` — restricted-dialect validator we own, test per keyword |
| MMO-003 disagreements survive into approval unresolved | sequencing | CONFIRMED | Per-disagreement AskUserQuestion resolution gate before ExitPlanMode |
| MMO-004 charter goes stale vs reconciled plan | correctness | CONFIRMED | Charter-impact classification; delta approved in plan, applied first post-approval |
| MMO-005 acceptance/waiver syntax undefined | correctness | PARTIAL | Checkbox + `[~] waived:` syntax defined; stable per-item IDs rejected (over-engineering) |
| MMO-006 prose→schema normalization unspecified | architecture | CONFIRMED | Codex defaults to `--output-schema`; `exec review` fallback gets a specified normalization stage with provenance |
| MMO-007 native findings can't join merge/stats | architecture | CONFIRMED | Native reviews reclassified as prerequisites, excluded from merge and stats |
| MMO-008 argv limits / budget units / duplication | operability | CONFIRMED | stdin input, bytes-with-headroom budget, no full-file+diff duplication (also hit live in the dogfood) |
| MMO-009 no portable timeout on macOS | operability | CONFIRMED | Watchdog subshell, process-group kill, traps, hanging-stub tests |
| MMO-010 memory-write authority self-contradictory | architecture | CONFIRMED | Single invariant: foreign/subagents propose, main Claude writes; caught a real contradiction between two phases |
| MMO-011 calibration ledger pools incomparable cohorts | correctness | PARTIAL | Versioned events (model id, prompt hash, schema version), CONFIRMED/PLAUSIBLE split; automated routing changes rejected — stays human |

Operational lessons from the dogfood run, folded into the runner contract:
Codex refuses an untrusted non-git cwd (`--skip-git-repo-check` + repo cwd
required); it reads stdin when non-tty (feed it or close it); a transport
failure can eat a 119k-token run mid-stream (retry-once policy, raw
preserved); an unconstrained reviewer with repo access burns its budget
exploring (exploration constraint now in the reviewer prompt).

## Out of scope

- No Orca integration changes (Orca remains Justin-driven; `/prime-agent`
  already serves it).
- No autonomous daemon/watchdog; gates stay human.
- No additional backends beyond Codex + Kimi in v1 — the config format makes
  adding GLM/DeepSeek later a config entry + smoke test, not code.
- Foreign-model writes happen only through the opt-in, per-instance
  permission gate (worktree-scoped, Claude-reviewed, Claude-committed);
  unattended/automatic foreign writes stay out of scope.
