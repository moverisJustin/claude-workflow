---
name: cross-review
description: Adversarial review by a DIFFERENT model family (OpenAI Codex CLI) for decorrelated blind spots — `code` mode reviews the branch diff, `design` mode reviews UI work for "looks like AI design" tells. Claude verifies every Codex finding against the actual code before reporting.
argument-hint: [code|design] [base-branch]
allowed-tools: Bash(codex:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*), Bash(bash ~/.claude/scripts/memory-context.sh *), Bash(bash .claude/scripts/memory-context.sh *), Read, Grep, Glob
---

# Cross-Review — second model family, decorrelated blind spots

A model reviewing its own family's output shares its blind spots. This skill
runs the review through **OpenAI Codex CLI** instead, then treats every Codex
finding as an unverified claim that Claude must try to refute against the
actual code before it reaches the user.

Arguments: `$ARGUMENTS` — mode (`code` default, or `design`) and optional base
branch (default `main`).

## 0. Probe the real CLI (never assume)

```bash
codex --version
```

- Missing → stop and report: install via the official Codex CLI instructions,
  then re-run. Do NOT fall back to reviewing with Claude and calling it a
  cross-review.
- Present → confirm the flags you're about to use exist (`codex exec --help`).
  Known-good surface on 0.144.x: `codex exec review --base <branch>`,
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
conventions and ruled-out decisions in view:

```bash
codex exec review --base <base-branch> \
  "$(cat /tmp/cross-review-memory.md)

Review the diff against the base. Honor the project memory above: do NOT raise
findings that merely restate an established convention or a ruled-out decision."
```

If the installed binary rejects a prompt argument alongside `review`, fall back
to `codex exec review --base <base-branch>` and fold the pack's key constraints
into a focus prompt instead. For security-only or single-subsystem focus, add it
to the same prompt argument. Capture the full output.

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

## Notes

- Codex model/auth comes from the user's own `~/.codex/config.toml` — don't
  override the model unless asked.
- This complements `/code-review` (same-family review), not replaces it. For
  release branches run both.
- Never let Codex apply fixes — it reviews read-only; fixes happen here,
  where the loop-closing contract applies.
- `scripts/memory-context.sh` is the reusable primitive for handing any
  foreign agent this repo's standing memory — same `run + prepend` works for a
  local model, an Orca agent, or a background task, not just Codex here.
