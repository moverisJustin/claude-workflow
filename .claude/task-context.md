# Task Context — feature/memory-migrate

## Objective
Add a way to convert dormant projects' pre-v3 Memory Banks to the v3 model,
auto-detected at session start (user's request: "run a check on startup, run
the skill if necessary").

## Design decision
Detect automatically (SessionStart hook), but OFFER rather than silently run —
migration archives files + rewrites memory (safe/reversible, but a state change
that shouldn't happen the moment you open a repo, before you've said why you're
there). So: startup detects → Claude offers → user confirms → one tap.

## Changes
- **skills/memory-migrate/SKILL.md** (new): converts an old-layout Memory Bank
  (activeContext/progress/sessionHistory/ROUTER/patterns, or older tasks/) —
  keeps the 3 durable files untouched, salvages real decisions→decisionLog and
  lessons→conventions (conservatively; skips stale session state), recreates
  useful patterns as skills, and ARCHIVES the retired files to
  .claude/memory/archive/ (reversible, never hard-deletes).
- **hook-session-start.sh**: detects retired-layout files and emits an
  "OFFER /memory-migrate" note (do-not-auto-run guard). Silent on v3-clean
  projects. Within the 1500-char cap.
- **test-hooks.sh**: +5 assertions (v3-clean silent, old-layout flagged, names
  the skill, offer-not-auto-run, tasks/ layout). 41/41.
- Docs: README/CHEATSHEET skill count 16→17, new skill rows, a "Migrating an
  old project" concept section. CI self-audit enforces the count.

## Verification
- hooks 41/41, install e2e 33/33, maintenance 7/7 + self-audit clean, drift 5/5,
  sync-lessons 17/17, plugin 8/8 — /bin/bash 3.2.

## Deploy after merge: git pull && ./install.sh (self-updates now).
