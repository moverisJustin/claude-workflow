---
id: dec-writing-contract-001
title: Writing Contract for Human-Facing Output (Brief Block, STE-Derived)
type: DEC
status: Accepted
version: 1.0.0
owner: Justin Keene
domain: engineering-workflow
created: 2026-08-11
updated: 2026-08-11
related:
  - dec-documentation-channels-001
  - arc-multi-model-orchestration-v1
---

# Writing Contract for Human-Facing Output (Brief Block, STE-Derived)

## Brief
**What this is.** A decision to write everything a human reads to one short contract, and to check it mechanically.
**Why.** Claude's output was thorough and hard to trace. It coined names without defining them, and asked for decisions without the facts to answer.
**What changes.**
- One always-on rule file holds 15 rules, derived from ASD-STE100 Issue 9.
- The rules bind one block, the `## Brief`, plus decision asks and turn summaries.
- The technical body of every document stays exempt, so AI readers lose nothing.
- A coined name goes in a `## Terms` register the first time anyone uses it.
- An open question goes in `## Open decision`, because chat scrolls and files do not.
- `scripts/ste-check.sh` blocks 6 faults and warns on 6 more.

**What you must decide.** Nothing. Justin settled both open assumptions on 2026-08-11.
**Risk.** A noisy checker teaches you to ignore it. The checker reads only the Brief block, and only six checks block.

## Context

Three distinct problems hid inside "Claude is too wordy", and each needed a
different fix:

| Problem | Symptom | Fix |
|---|---|---|
| Volume | Correct, thorough, hard to trace | Sentence and paragraph limits on the Brief |
| Undeclared names | A term appears mid-flow as if agreed | `## Terms` register, one word one meaning |
| Context-free asks | A question arrives without the facts | Decision brief, six fields, written to disk |

The third is not a language problem. A brief spoken into the chat stream is
still a message in a stream, and the reader checks in cold after an alert. By
then the question has scrolled away. That is why the decision brief is persisted
rather than only spoken.

## Decision

Adopt a **defined subset** of ASD-STE100 Simplified Technical English as a house
contract. Cite its rule numbers. Do not claim conformance.

Scope of the contract:

- **Binds**: the `## Brief` block on every human-read artifact, every request
  for a decision, and the end-of-turn summary.
- **Does not bind**: progress narration, the technical body of any document,
  code, or anything a machine parses.

Enforcement is mechanical, at gates that already exist:

| Gate | What runs |
|---|---|
| `hook-plan-gate.sh` (ExitPlanMode) | Brief check on the inline plan text |
| `/checks` | Brief check over changed markdown, `--allow-missing` |
| `/task-done` 2.6d | Brief check on the charter |
| `/task-done` step 6 | Brief check on the PR body before it is submitted |
| CI | Checker test suite, plus every doc in `specs/` |

## Copyright constraint

ASD-STE100 Issue 9 front matter states that no reproduction of the document, in
whole or in part, may be made without the written authority of an officer of
ASD. Its "Special usage rights" section grants irrevocable free reproduction to
eight categories: ASD member associations and their member companies, AIA and
AIAC members, ICCAIA members, customers of companies in those categories,
defense ministries of member countries, Airlines for America, airworthiness
authorities, and universities for educational purposes.

Moveris falls in none of those categories, and `claude-workflow` is a public
repository. Therefore this repo ships **our own rules, informed by the
standard**, citing rule numbers so a reader can look them up in their own free
copy from asd-ste100.org. No rule text and no dictionary content is reproduced.

This also rules out full conformance as a goal: conformance requires the ~900
word approved dictionary, which we can neither ship nor check. Several public
repositories have taken the opposite approach.

## Alternatives considered

**Full STE conformance.** Rejected. It needs the copyrighted dictionary, most
software vocabulary sits outside it, and STE bans the present perfect, which is
the natural tense for status reporting.

**Subset plus a local approved-word list.** Deferred. A gitignored house
glossary would tighten word choice without a copyright problem, but it adds a
second file to maintain for a marginal gain over the do-not-use list.

**Templates only, no checker.** Rejected. This repo already records the lesson
that prose in a skill file which never loads is a suggestion, not a contract
(`scripts/hook-plan-gate.sh:5`).

**Constrain every chat message.** Rejected. Blanket application makes running
commentary read clipped, and the pain is concentrated at decision points and
summaries.

## Consequences

**Cost, accepted.** Always-on context grew from 39,158 to 43,215 bytes, a net
add of 4,057 (+10.4%). `rules/` installs machine-wide, so every project pays it.
The original estimate was ~1,000 bytes. Justin accepted the cost on 2026-08-11
after seeing the measured figure.

**Scope, narrowed.** Justin ruled on 2026-08-11 that Linear and Forge do NOT
take a Brief. Both already carry their own structure, and Linear is a tracking
channel rather than something he reads to orient. The block goes on plans, BSpec
docs, PR bodies, handoffs, and `task-context.md`. Note that removing those two
did not reduce the always-on cost: `agents/` and `skills/` load on demand, and
only `CLAUDE.md` plus `rules/*.md` are always resident.

**The checker reads only the Brief.** This is what keeps false positives low
enough that findings stay worth reading, and it is what lets the technical body
stay as dense as it needs to be.

**Every finding prints a suggested rewrite.** A checker that reports "sentence 3
is 41 words" trains the reader to ignore it.

**Warnings never block.** Six deterministic checks block. The six heuristics
(passive voice, gerund openers, em-dashes, off-screen references, present
perfect, unregistered terms) only warn.

**Old files pass vacuously.** A `task-context.md` without `## Brief`, `## Terms`,
or `## Open decision` is not a defect. The requirement gates at the
`/task-branch` template, matching how `## Checkpoints` and `## Forge` were
introduced.

**The plan gate got stronger than designed.** A spike found that the
`ExitPlanMode` payload carries the plan text inline as `tool_input.plan`
alongside `planFilePath`. The published tool schema documents neither. The gate
checks the text it was handed, so it needs no path resolution and cannot race an
unlanded write.
