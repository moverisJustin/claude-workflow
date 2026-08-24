# Task Context

## Brief
**What this is.** Rules for how Claude writes in the running chat, plus a checker for any answer.
**Why.** The writing contract covered the Brief block and the turn summary. It left the running chat ungoverned, and that is where Justin gets lost.
**What changes.**
- `rules/writing.md` gains `## The chat stream`: 9 rules and 6 escape hatches.
- A new rule stops a coined name from standing in for its meaning.
- `ste-check.sh --chat` checks a pasted answer, with 3 new checks.
- The credit to the source project lands in the provenance section.
**What you must decide.** Whether the context cost is acceptable. It grew 4,029 bytes, not the 2,300 the plan promised.
**Risk.** The coined-name check finds capitalised names only, so it misses the common lowercase case.

## Branch
**Name**: claude/communication-style-adaptation-6db111
**Created**: 2026-08-23
**Author**: Justin @ Moveris
**Base**: main @ 335fddf
**Issue**: MOV-3307

## Objective
Bind the writing contract to the chat stream, the running text Justin reads during a
session. Justin named two problems: Claude coins a name for a thing or a task and then uses
the short name instead of saying what is happening, and Claude writes 30 words where 7
would do. Adapt `github.com/ayghri/i-have-adhd` (MIT) for the second problem, and write the
rule for the first, which that project does not cover.

This reverses one scope decision from MOV-3119. That branch listed "no constraint on
running progress narration" as a non-goal. Justin asked for exactly that constraint, so the
non-goal is superseded on purpose, not overlooked.

## Non-goals
- No Stop hook. Justin chose the pipe-in checker over an automatic per-turn warning.
- No time estimates and no five-item list cap. Both dropped from the source project.
- No new rule file and no new skill. The rule count stays 5.
- No change to the Brief block, the six-field decision brief, or the STE prose rules.
- No constraint on the body of a document, or on code.

## Acceptance
- [x] `rules/writing.md` carries `## The chat stream`: 9 rules, 6 escape hatches, MIT credit.
- [x] "Name the thing, not the label" requires a coined name to carry its plain meaning.
- [x] `ste-check.sh --chat` checks a whole answer and skips every Brief-shaped check.
- [x] Three checks added: `preamble` and `closer` block, `bare-coined-name` warns.
- [x] `scripts/test-ste-check.sh`: 57 passed, 0 failed.
- [x] `scripts/test-hooks.sh`: 88 passed, 0 failed. The plan gate still accepts a valid Brief.
- [x] `scripts/maintenance-check.sh` clean. Rules count still reads 5, so the README stays true.
- [x] `scripts/drift-check.sh` scores 99/100, unchanged.
- [x] The installed copy at `~/.claude/` matches the repo. Verified by diffing every
  installed path against its source, not by grepping for one marker string. The first
  install went stale, because I trimmed `rules/writing.md` afterwards; a second install
  fixed it. `rules/learned-patterns.md` is expected to differ, because its index is
  regenerated from the machine corpus and lesson publishing is opt-in.
- [x] Live test: an earlier answer from this session returned 2 true findings, 0 false.
- [ ] The `--last` flag from the wildcard step is NOT built. See Assumptions.

## Assumptions
- [ ] assumed: The context cost is acceptable. Measured, not estimated: 43,215 to 47,244
  bytes always-on, a net add of 4,029 (+9.3%). The approved plan promised about 2,300. The
  overrun sits in `rules/writing.md`, which grew 3,493 against a promised 2,300. `rules/`
  installs machine-wide, so every unrelated repo pays it. Cutting the six escape hatches
  would recover about 900 bytes, at the cost of the rules misfiring against `/clarify`,
  plan mode, and the confirm-before-destructive rule.
- [ ] assumed: The `--last` flag is not wanted now. The plan marked it optional and I did
  not build it, so the checker still needs a paste. If a checker that needs a paste is a
  checker you never run, this is the gap to close next.
- [~] accepted: I ran `./install.sh` from this unmerged branch, so the machine-global config
  carries the change before review. The installer backed up to
  `~/.claude/backups/workflow-20260823-150129`, so the rollback is a directory copy.
- [x] confirmed: This repo tracks work in Linear. MOV-3119 on the prior writing branch used
  the same team, so MOV-3307 follows the same path.

## Checkpoints
- [x] clarify: Asked 4 questions. Coined names to "pair name with meaning". Location to
  "extend rules/writing.md". Enforcement to "rule plus a pipe-in checker". Rules to keep to
  "end with one next action" only. Answered by reading instead of asking: the repo is
  public so the MIT credit is an obligation, `writing.md` already excluded progress
  narration by name, and `ste-check.sh` already had a coined-name detector scoped to the
  Brief.
- [x] wildcard: A `--last` flag reading the newest assistant message from the session
  transcript, so checking an answer costs one command and no clipboard step. Folded into
  the plan as optional. NOT built. Recorded in Assumptions as the open gap.
- [~] plan-review: waived. Justin approved the plan directly without asking for the foreign gate.
- [~] cross-review: waived pending PR review.

## Terms
- **chat stream** - the running text Claude writes to the user during a session, as opposed
  to a saved artifact like a plan, a spec, or a PR body.
- **gloss** - the plain meaning written next to a coined name, usually in parentheses.
- **escape hatch** - a named case where a chat rule does not apply, listed under
  `### When these rules lose` in `rules/writing.md`.

## Open decision
**What I need.** Your call on the always-on context overrun before PR #42 merges.
**Why it is blocked.** Nothing blocks. I finished the work and every gate passes. Only the trim decision stays open.
**What I found.**
- Always-on context grew 43,215 to 47,244 bytes, a rise of 9.3%.
- The approved plan promised about 2,300 bytes. The real number is 4,029.
- You accepted a similar rise of 10.4% on the earlier writing branch.
- The six escape hatches hold about 900 of those bytes.
**Options.**
- Accept the overrun. Cost: every project on this machine pays 4,029 bytes.
- Cut the escape hatches. Cost: recovers 900 bytes, and the chat rules then misfire against the clarification checkpoint, plan mode, and the confirm step.
**What I recommend.** Accept it. The hatches cost 900 bytes and stop the rules from fighting three checkpoints you rely on.
**If you say nothing.** I accept the overrun, mark the assumption accepted, and change nothing else.

## Loops
- **Linear**: MOV-3307 (In Review)
- **BSpec**: n/a — no new durable design. This edits the contract MOV-3119 already recorded
  at `specs/DEC-writing-contract-v1.0.0.md`.
- **Handoff**: none
- **Forge**: n/a — no forge repo configured for this project

## Decisions
| Decision | Why |
|---|---|
| Extend `rules/writing.md` rather than add a sixth rule file | One contract, one file. Two files about how Claude writes would drift apart, and the rule count stays 5 so no doc count moves. |
| Reverse the MOV-3119 non-goal on progress narration | Justin's reported problem lives entirely on that surface. |
| Rename the chat lists to `CHAT_OPENERS` and `CHAT_CLOSERS` | `CLOSERS` was already the sentence splitter's closing-punctuation string, defined later in the file, so it silently overwrote the chat list and the check fired on any line ending in a bracket. |
| Scope `bare-coined-name` to Title Case only | Every path, function, and flag in a coding session is backticked. Extending the check to them would produce enough noise to make the whole checker ignorable. |
| Drop the time estimates and the five-item cap | Justin's call. Estimates read as noise when Claude does the work in the same turn, and a hard cap truncates a real enumeration. |
