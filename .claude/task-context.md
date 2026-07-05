# Task Context — feature/phase4c-permissions

## Objective
Boris v3 upgrade, **Phase 4c: minimal permissions cleanup** (user chose the
minimal option — no new prompts for tools they use). Off main; Phases 0-3 + 4a
merged, 4b (#12) open.

## Changes (settings.base.json only)
- **Removed 35 dead `mcp__claude_ai_Linear__*` allow entries** — stale prefix;
  the live Linear server is `mcp__plugin_linear_linear__*` / a per-connection
  UUID, so these never matched. Net-neutral (Linear already prompted; approvals
  persist in the user's local settings). allow 226 → 191.
- **Normalized sudo grants** to the idiomatic `:*` suffix (some used ` *`).
- **Hardened the deny list** 25 → 39: added `rm -fr` flag-order variants, the
  no-space pipe-to-shell bypass (`curl *|bash`), `dd if=* of=/dev/*`, `mkfs*`,
  and `--force ... main*` trailing-arg force-push forms. Secret-read denies
  kept. (The destructive-guard PreToolUse hook remains the robust, order-
  independent layer; these static rules are the fallback.)
- Left `curl */ssh */wget *`/the Linux sudo grants intact — the user uses them
  (minimal cleanup, not aggressive tightening).
- test-install.sh: +3 assertions (no Linear entries, pipe-bypass deny present,
  sudo normalized). README settings row updated.

## Verification
- install e2e 30/30, hooks 36/36, drift 5/5, sync-lessons 17/17; settings valid
  JSON; hooks block (Phase 0 string matchers) untouched.

## Next
- 4d: plugin packaging, PRESERVE BARE NAMES (skills-dir form) — user's pick;
  install.sh survives (plugins can't ship permissions).
- 4e: LOCAL scheduled task (drift-check + doc-count verification) — user's pick.
