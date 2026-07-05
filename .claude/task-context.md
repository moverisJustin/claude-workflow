# Task Context — claude/festive-pike-877a96

## Objective
Boris v3 upgrade, **Phase 0: fix what's silently broken**. First PR of the approved
upgrade path (plan: "delete the machinery, keep the opinions") that modernizes the
repo against 2026 Claude Code — later phases adopt skills, native plan mode, /rewind,
/loop, the Workflow tool, plugins, and native memory.

## Why Phase 0 first
A 9-agent review found the hook layer — the repo's advertised safety net — was inert:
`settings.base.json` used object-form matchers and `$CLAUDE_TOOL_INPUT`/`$CLAUDE_FILE_PATH`
env vars that don't exist in the real hooks contract (string matchers, JSON on stdin).
Every reactive hook silently no-opped. Everything downstream assumes working hooks.

## Changes in this branch
- **Hook contract rewrite** (stdin JSON, python3 parsing, fail-open):
  - `hook-destructive-guard.sh`: compound-command detection; NON-mutating checkpoint
    (`git tag` + `git stash create/store` — never `stash push`, which yanked dirty work
    out of the tree); `permissionDecision: ask` for high-risk `rm -rf` targets;
    `-c tag.gpgsign=false` so signed-tag machines don't fail.
  - `hook-audit.sh` (new): replaces the two inert inline audit hooks.
  - `hook-prettier.sh` (new): replaces inline prettier hook; `npx --no-install`.
  - `hook-drift-watch.sh`: finally wired (PostToolUse + `if: Bash(git commit*)`),
    emits JSON `additionalContext` (plain stdout never reached context on PostToolUse).
  - `hook-precompact.sh` (new): PreCompact briefing-preservation directive — the
    mechanical replacement for the unenforceable 60%/75% Context Guardian protocol.
  - `hook-branch-switch.sh`: retired (log-only; advertised auto-stash never existed).
  - `settings.base.json`: hooks block rewritten to the documented format.
- **Latent bugs / supply chain**:
  - `sync-lessons.sh`: lessons now insert INSIDE the Learned Patterns section (EOF
    append broke dedup when a trailing section existed → infinite re-appends).
  - `test-sync-lessons.sh`: placement + idempotency assertions added.
  - `sync-agency-agents.sh`: upstream pinned to reviewed SHA 217a63b (env-overridable).
  - `install.sh`: community agents can no longer shadow core agents on basename collision.
- **CI**: `.github/workflows/ci.yml` — sync-lessons + hook-contract tests + drift-check
  smoke on ubuntu AND macos (`/bin/bash` = bash 3.2 floor). New `scripts/test-hooks.sh`.
- Docs updated in lockstep (README, CHEATSHEET, CLAUDE.md §7).

## Verification
- `scripts/test-hooks.sh`: 19/19 with /bin/bash 3.2
- `test-sync-lessons.sh`: 10/10 (new assertions fail against the old code)
- `drift-check.sh --json` smoke: OK; `settings.base.json` valid JSON
- Pinned-SHA fetch verified against GitHub

## Next phases (see ~/.claude/plans/calm-skipping-thunder.md)
1. Retirements: /checkpoint//rollback//undo → /rewind; mode system → plan mode;
   review/security commands → /code-review //security-review; verify-all → /verify.
2. commands/ → skills/ migration; boris → plan mode + Agent tool + saved Workflow.
3. Memory hybrid (keep conventions/decisionLog/projectContext + task-context.md;
   delete router/activeContext/sessionHistory machinery).
4. /ci-loop → /loop; model tiers; permissions overhaul; plugin packaging; scheduled
   maintenance routine.
