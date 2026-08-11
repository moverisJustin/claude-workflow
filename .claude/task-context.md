# Task Context

## Brief
**What this is.** A writing contract for the text a human reads, plus a checker that enforces it.
**Why.** Claude's output is thorough but hard to trace, it coins names without defining them, and it asks for decisions without the facts needed to answer.
**What changes.** A new always-on rule file. A `## Brief` block on every human-read artifact. A six-field form for every decision ask. A `## Terms` register for coined names. A checker wired into the existing gates.
**What you must decide.** Nothing. The four clarification answers settled the design.
**Risk.** The checker could be noisy. It reads only the Brief block, and only six checks can block.

## Branch
**Name**: claude/ste100-simplified-writing-0d5882
**Created**: 2026-08-11
**Author**: Justin @ Moveris
**Base**: main @ 801769d
**Issue**: N/A

## Objective
Give every human-facing surface a short, plain-English block at the top, written to a fixed
contract derived from ASD-STE100 Simplified Technical English. A human must be able to open a
plan, spec, PR, or Linear issue and know what is happening within a few sentences. The technical
body below the block stays as detailed as it is now, so other AI instances lose nothing.

## Non-goals
- No STE dictionary, no approved-word checking, and no claim of conformance to ASD-STE100.
- No constraint on the technical body of any document, or on running progress narration.
- No new skill. `/loops` and the turn summaries already cover checking in mid-run.
- No change to `hook-stop-verify.sh`, `foreign-review.sh`, or any review contract.

## Acceptance
- [x] `rules/writing.md` exists, holds the 15-rule contract and both block shapes. It is 2,980
  bytes, not the ~2,000 the plan estimated. See the Assumptions register.
- [x] The "Write plainly" hot-core lesson is a pointer, so the rule has one source.
- [x] `scripts/ste-check.sh` blocks on 6 deterministic faults and warns on 6 heuristics
  (`--list-checks` reports exactly 6 and 6).
- [x] Every finding from the checker prints a suggested rewrite, not just a violation line.
- [x] `scripts/test-ste-check.sh` passes: 30 assertions, 0 failures, including the vacuous-pass
  case and two regressions the checker found in its own branch charter.
- [x] The checker runs in `/task-done` (2.6d and again on the PR body), `/checks`, CI, and — not
  in the original plan — at plan approval, because the spike found the plan text arrives inline.
- [x] Every surface template in the plan's table carries a Brief or points at the contract.
- [x] `scripts/maintenance-check.sh` exits 0. It now also guards `## Brief`, `## Terms`, and
  `## Open decision` at the template, and audits the rules count that had already gone stale.
- [x] `scripts/drift-check.sh` scores 98/100, unchanged from the start of the branch.
- [x] No ASD-STE100 rule text or dictionary content lands in this public repo. `writing.md` cites
  rule numbers only and states that we do not claim conformance.

## Assumptions
- [ ] assumed: The Brief belongs in Linear issues and PR bodies read by other people, not only by
  Justin. If it is only for him, the Linear and Forge edits can be dropped.
- [ ] assumed: The always-on cost is acceptable. Measured, not estimated: 39,158 → 43,021 bytes,
  a net add of 3,863 (+9.9%). The plan promised ~1,000. The overrun is `writing.md` at 2,980
  instead of ~2,000, plus ~660 in `documentation-channels.md` and `CLAUDE.md`. `rules/` installs
  machine-wide, so an unrelated repo pays it too. Trimming the do-not-use list or the block
  templates would recover roughly 800 bytes at some cost to clarity.

## Checkpoints
- [x] clarify: Asked 4 questions. Conformance level → defined subset, cite STE rule numbers, no
  conformance claim. Chat scope → decision points plus turn summaries, not every message.
  Enforcement → validator wired into the existing gates. Context budget → ~2KB new file, shrink
  the duplicate hot-core lesson, net ~1KB. Answered by reading instead of asking: repo is public,
  ASD copyright bars redistribution, always-on is 39KB, no hook can rewrite a chat message.
- [x] wildcard: "The brief has to survive the scroll." A brief spoken into the chat stream is
  still a message in a stream; checking in 40 minutes late puts it 30 messages up. Folded in as
  `## Open decision` in this file, which `/loops`, `/session-start`, the PR body, and the
  foreign-review packs already read. Paired rule folded in: a decision brief must be
  self-contained, with no "as discussed above" and no pronoun pointing off-screen.
- [~] plan-review: waived — Justin approved the plan directly without requesting the foreign gate.
- [ ] cross-review: [backends + verdict]

## Terms
- **Brief** — the short plain-English block at the top of an artifact a human reads (coined 2026-08-11)
- **decision brief** — the six-field Brief variant used when Claude needs an answer (coined 2026-08-11)
- **Terms register** — this section; the branch's list of coined names and their definitions (coined 2026-08-11)

## Open decision
None.

## Plan
- [ ] `rules/writing.md` — the contract
- [ ] Shrink the duplicate hot-core lesson to a pointer, then reindex
- [ ] `scripts/ste-check.sh` + `scripts/test-ste-check.sh`
- [ ] Spike whether `hook-plan-gate.sh` can reach the plan file
- [ ] Wire the checker into `/task-done`, `/checks`, and CI
- [ ] Add the Brief to every surface template
- [ ] Bookkeeping: CLAUDE.md, README, CHEATSHEET, install.sh, the two existing specs
- [ ] Run the full verification suite

## Loops
- **Linear**: OPEN
- **BSpec**: OPEN
- **Handoff**: none
- **Forge**: OPEN

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-08-11 | Ship our own rules informed by ASD-STE100, citing rule numbers, reproducing no rule text or dictionary | Issue 9 front matter bars reproduction without ASD's written authority. The "Special usage rights" grant covers 8 organization categories; Moveris is in none. This repo is public. |
| 2026-08-11 | The checker reads only the `## Brief` block, never the technical body | Keeps the false-positive rate low and matches the ask: plain summary on top, normal technical detail below. |
| 2026-08-11 | Persist the open decision to this file rather than only speaking it | Justin reads cold after an alert. A brief in the chat stream scrolls away; this file is already read by `/loops`, `/session-start`, the PR body, and every foreign-review pack. |
| 2026-08-11 | No new skill | `/loops` and the turn summaries already cover checking in mid-run. Adding one widens the surface `maintenance-check.sh` audits for no new capability. |

## Progress
### Done
- Researched ASD-STE100 Issue 9 from the official specification: 53 rules in 9 sections, ~900
  approved words, copyright terms, and the Issue 9 rename of "technical name" to "technical noun".
- Inventoried every human-facing prose surface in the repo.
- Plan written and approved.
- `rules/writing.md`, and the hot-core lesson reduced to a pointer.
- `scripts/ste-check.sh` and `scripts/test-ste-check.sh` (30 assertions).
- Spiked the plan gate, then wired it. The gate denies a plan whose Brief has errors.
- Wired the checker into `/task-done`, `/checks`, and CI.
- Brief or decision-brief added to 12 surface templates.
- Bookkeeping: CLAUDE.md, README, install.sh, both specs, drift-check, maintenance-check.
- Full verification: 6 suites, 205 assertions, 0 failures.

### In Progress
- Nothing. The work is complete and unreviewed.

### Blocked
- [nothing blocked]

## Notes
The extension mechanism for domain vocabulary in ASD-STE100 is rules 1.5 (technical nouns) and
1.12 (technical verbs). Rule 1.12 explicitly contemplates software verbs such as `click`, `delete`,
and `drag`. The `## Terms` register above is that mechanism applied to our domain, and it is the
direct fix for Claude coining a name and then using it as if it were agreed.

The repo already treats a missing section in an older `task-context.md` as a vacuous pass rather
than a defect. `## Terms` and `## Open decision` follow that convention.
