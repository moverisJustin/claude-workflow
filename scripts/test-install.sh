#!/usr/bin/env bash
set -uo pipefail

# End-to-end installer test in a throwaway fake HOME. Verifies the Boris v3
# install against a machine that has an OLD (v2.0-era) ~/.claude: fat
# CLAUDE.md with private lessons, retired command flat-copies, retired hook
# scripts. Asserts migration, retirement, idempotency, and — critically —
# that a private (untagged) lesson never leaks into the repo tree.
# Pure bash + the installer's own deps. Exits non-zero on any failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_HOME="$TMP/home"
CD="$FAKE_HOME/.claude"
mkdir -p "$CD/commands" "$CD/scripts"

pass=0
fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "=== test-install.sh ==="

# --- Fixture: an old v2.0-era machine ---
# Includes: a private lesson (must migrate, must never leak), a user-authored
# custom section (must be carried over), and — critically — a PRE-EXISTING
# heading-only rules file, which once made the migration die silently while
# reporting success (Phase 6.3 skips seeding, sync used to crash on the empty
# section, || true hid it, CLAUDE.md was replaced, lessons gone).
mkdir -p "$CD/rules"
printf '# Learned Patterns\n' > "$CD/rules/learned-patterns.md"

cat > "$CD/CLAUDE.md" <<'EOF'
# Session Boot (MANDATORY)

Old boot prose.

# Quick Reference (Boris v2.0)

```bash
/verify-all          # old command
```

# My Custom Company Standards

- Internal API host: keep following these even after upgrades.

# Learned Patterns

### Existing shared pattern
Also lives in the repo rules file? No - machine-only for this test.

### fly secrets private machine lesson
`fly secrets set` does NOT rebuild the image. Private, untagged - must NOT leak.

EOF
echo "old checkpoint command" > "$CD/commands/checkpoint.md"
echo "old session-start command" > "$CD/commands/session-start.md"
echo "#!/bin/bash" > "$CD/scripts/hook-branch-switch.sh"
# Retired-WITHOUT-successor stragglers (no same-named skill/agent to trigger the
# skill-based cleanup): load-context (retired P3), ci-integrator (retired 4b).
echo "old load-context command" > "$CD/commands/load-context.md"
mkdir -p "$CD/agents"; echo "old ci-integrator agent" > "$CD/agents/ci-integrator.md"
# An old install deployed ALL community agents; the now-opt-in ones must be
# pruned on upgrade (but never the user's own custom agents).
echo "old opt-in community agent" > "$CD/agents/marketing-seo-specialist.md"
echo "my own custom agent" > "$CD/agents/my-custom-agent.md"

# Snapshot the repo's lessons file to prove the install never mutates it
REPO_LESSONS_BEFORE=$(cat "$REPO_DIR/rules/learned-patterns.md")

# --- Run the installer against the fake HOME ---
if ! HOME="$FAKE_HOME" SKIP_SIGNING_SETUP=1 BORIS_INSTALL_NO_SELF_UPDATE=1 bash "$REPO_DIR/install.sh" > "$TMP/install1.log" 2>&1; then
  echo "FAIL: install.sh exited non-zero"; tail -20 "$TMP/install1.log"; exit 1
fi

# --- Assertions: CLAUDE.md slimmed + lessons migrated ---
if grep -q "boris-version: 3" "$CD/CLAUDE.md"; then ok "CLAUDE.md replaced with Boris v3 structure (version stamp present)"; else bad "CLAUDE.md not upgraded to v3"; fi
LINES=$(wc -l < "$CD/CLAUDE.md" | tr -d ' ')
if [ "$LINES" -lt 150 ]; then ok "installed CLAUDE.md is slim ($LINES lines < 150)"; else bad "installed CLAUDE.md too big ($LINES lines)"; fi
if ! grep -q '^# Learned Patterns' "$CD/CLAUDE.md"; then ok "lessons no longer live in CLAUDE.md"; else bad "CLAUDE.md still carries a Learned Patterns section"; fi
if grep -q "fly secrets private machine lesson" "$CD/rules/learned-patterns.md" 2>/dev/null; then
  ok "private lesson migrated into a PRE-EXISTING heading-only rules file"
else
  bad "private lesson LOST in migration (empty-section regression)"
fi
if grep -q "# My Custom Company Standards" "$CD/CLAUDE.md" && grep -q "Internal API host" "$CD/CLAUDE.md"; then
  ok "user's custom section carried over into the new CLAUDE.md"
else
  bad "user's custom section silently destroyed"
fi
if grep -q "### Em-dashes are an LLM writing tell" "$CD/rules/learned-patterns.md" 2>/dev/null; then
  ok "repo shared lessons synced down into the machine rules file"
else
  bad "repo lessons did not sync down"
fi

# --- The privacy gate: repo tree untouched by the machine's private lesson ---
if [ "$(cat "$REPO_DIR/rules/learned-patterns.md")" = "$REPO_LESSONS_BEFORE" ]; then
  ok "repo rules/learned-patterns.md unchanged (no private-lesson leak)"
else
  bad "REPO LESSONS FILE MUTATED - privacy gate broken"
fi

# --- Rules, skills, workflows, agents ---
for r in git-safety.md workflow.md learned-patterns.md; do
  if [ -f "$CD/rules/$r" ]; then ok "rules/$r installed"; else bad "rules/$r missing"; fi
done
SKILLS=$(ls -d "$CD/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
REPO_SKILLS=$(ls -d "$REPO_DIR/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$SKILLS" -eq "$REPO_SKILLS" ]; then ok "all $REPO_SKILLS skills installed"; else bad "skills installed=$SKILLS expected=$REPO_SKILLS"; fi
if [ -f "$CD/workflows/boris-build.js" ]; then ok "boris-build workflow installed"; else bad "workflow missing"; fi
if [ -f "$CD/agents/code-architect.md" ]; then ok "agents installed"; else bad "agents missing"; fi
# Core agents carry explicit model tiers
if grep -q '^model: opus' "$CD/agents/code-architect.md"; then ok "core agent has model tier (code-architect: opus)"; else bad "core agent missing model tier"; fi
# Community: only MANIFEST-active agents install (not all vendored), with tiers
# injected. Extract slugs the SAME way install.sh does (strip inline comments).
active_slugs() { sed 's/#.*//' "$REPO_DIR/agents/community/MANIFEST.txt" | while IFS= read -r l; do s=$(printf '%s' "$l" | xargs); [ -n "$s" ] && echo "$s"; done; }
ACTIVE=$(active_slugs | wc -l | tr -d ' ')
VENDORED=$(ls "$REPO_DIR/agents/community/"*.md 2>/dev/null | wc -l | tr -d ' ')
INSTALLED_COMM=0
while IFS= read -r slug; do
  [ -f "$CD/agents/$slug.md" ] && INSTALLED_COMM=$((INSTALLED_COMM + 1))
done < <(active_slugs)
if [ "$INSTALLED_COMM" -eq "$ACTIVE" ] && [ "$ACTIVE" -lt "$VENDORED" ]; then
  ok "only active community agents installed ($INSTALLED_COMM of $VENDORED vendored)"
else
  bad "community install wrong (installed=$INSTALLED_COMM active=$ACTIVE vendored=$VENDORED)"
fi
# A commented-out (opt-in) agent must NOT be installed — and a now-inactive one
# left by an OLD all-community install must be PRUNED on upgrade...
if [ ! -f "$CD/agents/marketing-seo-specialist.md" ]; then ok "inactive community agent pruned on upgrade (not installed/left behind)"; else bad "inactive community agent survived"; fi
# ...but the user's own custom agent must be left untouched
if [ -f "$CD/agents/my-custom-agent.md" ]; then ok "user's custom agent preserved (prune only touches vendored community)"; else bad "prune deleted a user custom agent"; fi
# An installed community agent got a model tier at deploy time
SAMPLE=$(active_slugs | head -1)
if grep -q '^model:' "$CD/agents/$SAMPLE.md" 2>/dev/null; then ok "community agent got a deploy-time model tier ($SAMPLE)"; else bad "community agent missing injected model tier"; fi
# Vendored repo files stay pristine (tiering is deploy-time only)
if ! grep -q '^model:' "$REPO_DIR/agents/community/$SAMPLE.md"; then ok "vendored community file stays upstream-pristine (no model: in repo)"; else bad "vendored file was mutated with model:"; fi

# --- Retirements ---
if [ ! -f "$CD/commands/checkpoint.md" ]; then ok "retired command removed"; else bad "retired checkpoint.md survived"; fi
if [ ! -f "$CD/commands/session-start.md" ]; then ok "superseded command copy removed (skill replaces it)"; else bad "superseded session-start.md survived"; fi
# Retired-without-successor stragglers must be removed even though no skill/agent
# of the same name exists to trigger the skill-based cleanup.
if [ ! -f "$CD/commands/load-context.md" ]; then ok "retired-without-successor command removed (load-context)"; else bad "stale load-context.md survived upgrade"; fi
if [ ! -f "$CD/agents/ci-integrator.md" ]; then ok "retired-without-successor agent removed (ci-integrator)"; else bad "stale ci-integrator.md survived upgrade"; fi
if [ ! -d "$CD/commands" ]; then ok "empty commands/ dir removed"; else bad "commands/ dir remains"; fi
if [ ! -f "$CD/scripts/hook-branch-switch.sh" ]; then ok "retired hook script removed"; else bad "retired hook script survived"; fi
if [ -f "$CD/scripts/hook-stop-verify.sh" ]; then ok "current hook scripts installed"; else bad "hook scripts missing"; fi

# --- Settings (only when jq available; installer skips the merge without it) ---
if command -v jq >/dev/null 2>&1; then
  if jq -e '.hooks.Stop' "$CD/settings.json" >/dev/null 2>&1; then ok "settings.json installed with Stop hook wiring"; else bad "settings.json hooks wrong"; fi
  # Permissions cleanup (Phase 4c)
  LINEAR=$(jq -r '[.permissions.allow[] | select(test("Linear"))] | length' "$CD/settings.json")
  if [ "$LINEAR" = "0" ]; then ok "no stale Linear MCP allow entries"; else bad "$LINEAR stale Linear entries remain"; fi
  if jq -e '[.permissions.deny[] | select(. == "Bash(curl *|bash)")] | length > 0' "$CD/settings.json" >/dev/null; then ok "deny covers no-space pipe-to-shell bypass"; else bad "deny missing pipe bypass hardening"; fi
  if jq -e '[.permissions.allow[] | select(startswith("Bash(sudo ") and endswith(" *)"))] | length == 0' "$CD/settings.json" >/dev/null; then ok "sudo grants normalized to :* form"; else bad "inconsistent sudo grant syntax remains"; fi
fi

# --- Idempotency: second run must not duplicate migrated lessons ---
if ! HOME="$FAKE_HOME" SKIP_SIGNING_SETUP=1 BORIS_INSTALL_NO_SELF_UPDATE=1 bash "$REPO_DIR/install.sh" > "$TMP/install2.log" 2>&1; then
  echo "FAIL: second install.sh run exited non-zero"; tail -20 "$TMP/install2.log"; exit 1
fi
N=$(grep -cF "### fly secrets private machine lesson" "$CD/rules/learned-patterns.md" || true)
if [ "$N" -eq 1 ]; then ok "second run idempotent (private lesson count still 1)"; else bad "second run duplicated lessons (count=$N)"; fi
if grep -q "already at Boris v3" "$TMP/install2.log"; then ok "second run detects v3 CLAUDE.md"; else bad "second run re-migrated CLAUDE.md"; fi
if [ "$(cat "$REPO_DIR/rules/learned-patterns.md")" = "$REPO_LESSONS_BEFORE" ]; then
  ok "repo lessons still unchanged after second run"
else
  bad "second run mutated the repo lessons file"
fi

echo ""
echo "Passed: $pass  Failed: $fail"
[ "$fail" -ne 0 ] && exit 1
echo "All installer assertions passed."
