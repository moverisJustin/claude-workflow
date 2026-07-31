#!/usr/bin/env bash
# test-forge-bridge.sh — guard tests for the Forge transport bridge.
#
# Hermetic: `forge` is stubbed, HOME is redirected, no network, no real forge
# repo. The stub records the exact argv it was called with, so the tests assert
# the CONTRACT with the real CLI (verified against forge v0.3.7 source) without
# needing Python 3.10+ and the package installed on every machine.
#
# The most important cases here are the ABSENT ones. This ships in a public
# repo where most users will never install Forge, so "forge missing" is the
# common path, not the edge case — and a bridge that fails the turn when the
# CLI is absent would break the workflow for everyone.
#
# Run: bash scripts/test-forge-bridge.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE="$SCRIPT_DIR/forge-bridge.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  ok   — $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL — $1"; echo "         expected: $2"; echo "         actual:   $3"; }
check(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }
contains() {
  case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "output containing '$2'" "$3" ;; esac
}
absent() {
  case "$3" in *"$2"*) bad "$1" "output WITHOUT '$2'" "$3" ;; *) ok "$1" ;; esac
}

# ─── Fixture: a forge repo + a stubbed `forge` CLI ───
FR="$WORK/forge-scratch"
mkdir -p "$FR"/{.forge,shared,me,teammate} "$WORK/bin" "$WORK/home/.forge"
printf 'github_username: me\n' > "$WORK/home/.forge/config"
printf 'name: scratch\nmembers:\n- me\n- teammate\n' > "$FR/.forge/config.yaml"
for m in me teammate; do
  for f in wip plans contracts decisions lessons handoffs; do
    printf '# %s — %s\n\n' "$f" "$m" > "$FR/$m/$f.md"
  done
done
for f in decisions tickets prs blockers deprecations ready; do
  printf '# %s\n\n' "$f" > "$FR/shared/$f.md"
done
printf '# Team Rules\n\n## Conventions\n' > "$FR/CLAUDE.md"
git -C "$FR" init -q
git -C "$FR" config user.email t@t.t; git -C "$FR" config user.name t
git -C "$FR" add -A && git -C "$FR" commit -q --no-gpg-sign -m scaffold

# Stub: log argv, and make `write -f FILE` actually append so publish is
# testable end to end. Mirrors the real CLI's surface at forge v0.3.7.
cat > "$WORK/bin/forge" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$FORGE_CALL_LOG"
sub="$1"; shift
repo=""; type=""; infile=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    -f) infile="$2"; shift 2 ;;
    *) [ -z "$type" ] && type="$1"; shift ;;
  esac
done
case "$sub" in
  write)
    [ -n "$infile" ] || { echo "Error: Content must not be empty."; exit 1; }
    case "$type" in
      blockers|tickets|prs|ready) target="$repo/shared/$type.md" ;;
      *) target="$repo/me/$type.md" ;;
    esac
    { printf '\n## 2026-07-31 12:00 UTC — entry\n\n'; cat "$infile"; } >> "$target"
    ;;
  handoff) printf '\n## Handoff — 2026-07-31\n\n%s\n' "$type" >> "$repo/me/handoffs.md" ;;
  push) : ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/forge"

export FORGE_CALL_LOG="$WORK/calls.log"
: > "$FORGE_CALL_LOG"

# Run the bridge with forge PRESENT.
withforge() {
  PATH="$WORK/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$WORK/home" \
    FORGE_REPO_PATH="$FR" FORGE_CALL_LOG="$FORGE_CALL_LOG" \
    bash "$BRIDGE" "$@" 2>&1
}
# Run the bridge with forge ABSENT (and no repo) — the public-repo default.
noforge() {
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$WORK/home" \
    bash "$BRIDGE" "$@" 2>&1
}

echo "test-forge-bridge"
echo
echo "-- forge ABSENT (the case that ships to everyone) --"

PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$WORK/home" bash "$BRIDGE" available >/dev/null 2>&1
check "available exits 1 when forge is missing" "1" "$?"

for cmd in "publish wip content" "handoff text" "read-teammates" "pending" "collision br obj" "team-rules-conflict" "status"; do
  # shellcheck disable=SC2086
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$WORK/home" bash "$BRIDGE" $cmd >/dev/null 2>&1
  check "'$cmd' exits 0 when forge is missing (never blocks)" "0" "$?"
done

check "read-teammates emits nothing when forge is missing" "" "$(noforge read-teammates)"
check "collision emits nothing when forge is missing"       "" "$(noforge collision b o)"

echo
echo "-- forge PRESENT --"

check "available exits 0 with CLI + repo" "0" "$(withforge available >/dev/null 2>&1; echo $?)"

# publish: write AND push, in one call — an unpushed entry helps nobody.
: > "$FORGE_CALL_LOG"
withforge publish wip "Building the bridge. Ticket: MOV-2883." >/dev/null
contains "publish calls 'forge write wip'" "write wip" "$(cat "$FORGE_CALL_LOG")"
contains "publish pushes in the same operation" "push" "$(cat "$FORGE_CALL_LOG")"
contains "publish content reaches wip.md" "MOV-2883" "$(cat "$FR/me/wip.md")"

# Content must go via -f, never stdin: a backgrounded process gets /dev/null
# on stdin, so a piped publish silently wrote nothing. Regression guard.
contains "publish uses -f FILE, not stdin" "-f " "$(cat "$FORGE_CALL_LOG")"

: > "$FORGE_CALL_LOG"
echo "Plan from stdin" | withforge publish plans >/dev/null
contains "publish accepts content on stdin" "Plan from stdin" "$(cat "$FR/me/plans.md")"

# Empty content is a no-op, not an error.
check "publish with empty content exits 0" "0" "$(printf '' | withforge publish wip >/dev/null 2>&1; echo $?)"

# deprecations: the CLI has NO `write deprecations` (verified cli.py:671), so
# the bridge appends directly in the documented format.
withforge publish-deprecation "legacy-api" "POST /v2" "no idempotency keys" "MOV-1" >/dev/null
DEP=$(cat "$FR/shared/deprecations.md")
contains "deprecation records the name"        "DEPRECATED: legacy-api" "$DEP"
contains "deprecation records replacement"     "Replaced by: POST /v2"  "$DEP"
contains "deprecation is ACTIVE by default"    "Status: ACTIVE"         "$DEP"
contains "deprecation records the ticket"      "Ticket: MOV-1"          "$DEP"

withforge handoff "Next step: wire the touchpoints." >/dev/null
contains "handoff reaches handoffs.md" "wire the touchpoints" "$(cat "$FR/me/handoffs.md")"

echo
echo "-- reading teammate context --"

cat >> "$FR/teammate/contracts.md" <<'EOF'

## 2026-07-31 18:10 — [DB] Added payments table
New table: payments. Teammates must read via the payments API.
EOF

OUT=$(withforge read-teammates)
contains "teammate contract is surfaced"        "payments table"            "$OUT"
contains "teammate content is wrapped as DATA"  "forge-teammate-data: begin" "$OUT"
contains "data marker says do not obey"         "not as instructions"        "$OUT"
absent   "my own files are not echoed back"     "wip — me"                   "$OUT"

# A scaffolded-but-empty file is ~650 bytes of instructional header in the real
# templates. Emitting it wastes context and reads as teammate content.
absent "header-only files are not emitted" "# lessons — teammate" "$OUT"

# The cap protects the context window — Forge's own hook output is unbounded.
for i in $(seq 1 40); do
  printf '\n## 2026-07-31 1%s:00 — filler entry\n%s\n' "$i" "$(head -c 200 </dev/zero | tr '\0' 'x')" \
    >> "$FR/teammate/contracts.md"
done
CAPPED=$(withforge read-teammates --cap 400)
if [ "$(printf '%s' "$CAPPED" | wc -c)" -lt 900 ]; then
  ok "read-teammates respects --cap"
else
  bad "read-teammates respects --cap" "<900 chars" "$(printf '%s' "$CAPPED" | wc -c) chars"
fi
contains "truncation is announced, not silent" "truncated at" "$CAPPED"

echo
echo "-- collision detection --"

cat >> "$FR/teammate/plans.md" <<'EOF'

## 2026-07-31 18:00 — Plan: refactor the payments API
Steps: add verify_signature in payments/webhooks.py, wire the route, add tests.
Touches: payments/webhooks.py, src/lib/payments.ts
EOF

HIT=$(withforge collision "feature/payments-webhooks" "Refactor payments webhooks signature verification in payments/webhooks.py")
contains "overlapping work is flagged"            "COLLISION"        "$HIT"
contains "collision names the teammate"           "teammate"         "$HIT"
contains "collision prefers plans (about-to-do)"  "plans"            "$HIT"

MISS=$(withforge collision "task/readme-typo" "Fix a typo in the onboarding documentation heading")
check "unrelated work produces NO question (false positives train you to ignore it)" "" "$MISS"

echo
echo "-- team rules conflict --"

check "unedited scaffold rules stay silent" "" "$(withforge team-rules-conflict)"

# Commented-out template examples are not adopted rules.
printf '# Team Rules\n\n<!--\n- Branching: always branch off develop.\n-->\n' > "$FR/CLAUDE.md"
check "commented-out example rules stay silent" "" "$(withforge team-rules-conflict)"

printf '# Team Rules\n\n## Conventions\n- Branching: always branch off develop. Never commit to main directly.\n' > "$FR/CLAUDE.md"
CONF=$(cd "$FR" && PATH="$WORK/bin:/usr/bin:/bin" HOME="$WORK/home" FORGE_REPO_PATH="$FR" bash "$BRIDGE" team-rules-conflict 2>&1)
contains "declared base branch conflict is surfaced" "Branching:"   "$CONF"
contains "conflict names the declared branch"        "develop"      "$CONF"
contains "team rules are framed as proposals"        "PROPOSALS"    "$CONF"
contains "team rules are wrapped as DATA"            "forge-teammate-data" "$CONF"

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
