# Task Context — feature/phase4d-plugin

## Objective
Boris v3 upgrade, **Phase 4d: optional plugin marketplace** (FINAL phase).
User chose "additive marketplace, keep install.sh" AFTER I corrected the
premise: plugins ALWAYS namespace bundled skills (/boris-workflow:task-done);
there is NO bare-name plugin form. So install.sh stays the primary bare-name
path, and the plugin is a purely additive, optional onramp.

## Changes
- **.claude-plugin/plugin.json**: name boris-workflow v3.0.0; `agents` = an
  EXPLICIT list of the 8 core agents (a custom-path list REPLACES the default
  agents/ scan per the plugin spec, so the 105 community agents are NOT
  bundled); `skills` defaults to skills/ (16 skills, namespaced); hooks ->
  ./hooks/hooks.json.
- **.claude-plugin/marketplace.json**: marketplace "boris" listing the
  boris-workflow plugin with source "./" (repo IS the single plugin).
  Install: /plugin marketplace add moverisJustin/claude-workflow then
  /plugin install boris-workflow@boris.
- **hooks/hooks.json**: GENERATED from settings.base.json with
  ${CLAUDE_PLUGIN_ROOT}/scripts/ paths — all 8 hooks, so plugin users get the
  full safety/audit layer. A CI test asserts it stays in sync with
  settings.base.json (no drift).
- **scripts/test-plugin.sh** (new, in CI): 8 checks — manifests valid, agents
  list = core set with no community, marketplace source, hooks reference real
  plugin-rooted scripts, hook-wiring parity with settings.base.json, and
  `claude plugin validate` (passes locally).
- Docs: README "Install as a plugin (optional)" section + What-You-Get row.
  Honest about the tradeoffs (namespaced commands; community agents / saved
  workflow / permissions / rules are install.sh-only; use one path not both).

## Verification
- test-plugin 8/8 (incl. claude plugin validate), install e2e 30/30, hooks
  36/36, drift 5/5, sync-lessons 17/17 — /bin/bash 3.2.

## Upgrade COMPLETE after this + #14 (4e) merge.
