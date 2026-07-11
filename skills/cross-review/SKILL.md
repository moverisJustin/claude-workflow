---
name: cross-review
description: Adversarial review by a DIFFERENT model family (OpenAI Codex CLI) for decorrelated blind spots — `code` mode reviews the branch diff, `design` mode reviews UI work for "looks like AI design" tells. Claude verifies every Codex finding against the actual code before reporting.
argument-hint: [code|design] [base-branch]
allowed-tools: Bash(codex:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*), Read, Grep, Glob
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

## 1a. Code mode (default)

```bash
codex exec review --base <base-branch>
```

If custom focus is needed (security-only, a specific subsystem), pass review
instructions as the prompt argument. Capture the full output.

## 1b. Design mode

For UI/UX changes — components, styles, layouts, marketing pages. Codex has
sharper taste for generic-AI design tells, so give it both the code and the
pixels:

1. Collect the UI diff (`git diff <base>...HEAD -- '*.tsx' '*.jsx' '*.css'
   '*.svelte' '*.vue' '*.html'` — adapt to the stack).
2. If screenshots exist (from `/verify`, the Browser pane, or the user),
   attach them: `-i shot1.png -i shot2.png`.
3. Write a JSON Schema for findings to a scratch file (fields: `file`, `line`,
   `summary`, `why_it_reads_as_ai`, `suggestion`, `severity`) and run:

```bash
codex exec -s read-only --output-schema <schema-file> \
  -i <screenshots...> "<design review prompt + the diff on stdin>" < diff.txt
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
