#!/usr/bin/env bash
# test-review-merge.sh — guard tests for skills/cross-review/review-merge.mjs.
#
# Covers: backend-tagged arg parsing, the dedup key (file + line within 3 +
# category), agreement marking (2+ distinct backends), near-miss lines staying
# separate, cross-category same-line staying separate, malformed-input fail
# loud (nonzero exit + stderr, no stdout), and deterministic severity/file
# ordering.
#
# Offline: bash + system node only. No network, no AI. Run after any change to
# review-merge.mjs.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUT="$SCRIPT_DIR/../skills/cross-review/review-merge.mjs"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

assert_contains() { # <desc> <haystack> <needle>
  case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (missing: $3)" ;; esac
}
assert_not_contains() { # <desc> <haystack> <needle>
  case "$2" in *"$3"*) fail "$1 (unexpected: $3)" ;; *) pass "$1" ;; esac
}
assert_eq() { # <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (want '$2' got '$3')"; fi
}

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: node not found on PATH" >&2
  exit 1
fi
if [ ! -f "$SUT" ]; then
  echo "FAIL: review-merge.mjs not found at $SUT" >&2
  exit 1
fi

DIR="$(mktemp -d "${TMPDIR:-/tmp}/rvmerge.XXXXXX")"
trap 'rm -rf "$DIR"' EXIT

# --- fixtures ---------------------------------------------------------------
# codex: 4 findings — the both-flagged one, a near-miss anchor, a cross-
# category same-line one, and a low-severity late-file one (for ordering).
cat > "$DIR/codex.json" <<'EOF'
{
  "findings": [
    {
      "severity": "high",
      "category": "correctness",
      "summary": "BOTHFLAGGED off-by-one in pagination",
      "failure_scenario": "Last page drops the final row.",
      "file": "src/a.js",
      "line": 10,
      "lessons": [{ "pattern": "LESSON_CODEX boundary loops" }]
    },
    {
      "severity": "high",
      "category": "correctness",
      "summary": "NEARMISS unchecked null deref",
      "failure_scenario": "Missing user object crashes render.",
      "file": "src/b.js",
      "line": 40
    },
    {
      "severity": "medium",
      "category": "correctness",
      "summary": "XCAT_CORRECTNESS stale cache read",
      "failure_scenario": "Reads pre-update value after write.",
      "file": "src/c.js",
      "line": 7
    },
    {
      "severity": "low",
      "category": "design",
      "summary": "ZLOW uniform border radii",
      "failure_scenario": "Reads as templated AI design.",
      "file": "src/z.css",
      "line": 3
    }
  ],
  "coverage_notes": "COVERAGE_CODEX did not review generated files"
}
EOF

# kimi: dup of the both-flagged one (line within 3, higher severity), a
# near-miss 5 lines away, a cross-category same-line finding, and an
# early-file critical (for ordering).
cat > "$DIR/kimi.json" <<'EOF'
{
  "findings": [
    {
      "severity": "critical",
      "category": "correctness",
      "summary": "BOTHFLAGGED pagination loses last element",
      "failure_scenario": "Page N omits its last item.",
      "file": "src/a.js",
      "line": 12,
      "lessons": [{ "pattern": "LESSON_KIMI paginate off the total count" }]
    },
    {
      "severity": "high",
      "category": "correctness",
      "summary": "NEARMISS_FAR separate null issue",
      "failure_scenario": "Different guard five lines away.",
      "file": "src/b.js",
      "line": 45
    },
    {
      "severity": "medium",
      "category": "test-gap",
      "summary": "XCAT_TESTGAP cache path untested",
      "failure_scenario": "Regression ships with green CI.",
      "file": "src/c.js",
      "line": 7
    },
    {
      "severity": "critical",
      "category": "spec-drift",
      "summary": "AEARLY returns epoch not ISO-8601",
      "failure_scenario": "Spec requires ISO-8601 timestamps.",
      "file": "src/api.js",
      "line": 99
    }
  ]
}
EOF

printf 'this is not json {' > "$DIR/broken.json"
printf '{"not_findings": []}' > "$DIR/nofindings.json"

# --- 1. dedup + agreement ---------------------------------------------------
echo "dedup + agreement"
out="$(node "$SUT" "codex:$DIR/codex.json" "kimi:$DIR/kimi.json" 2>/dev/null)"; rc=$?
assert_eq "exits 0 on valid input" 0 "$rc"

nboth="$(printf '%s\n' "$out" | grep -c 'BOTHFLAGGED')"
assert_eq "same file/line-within-3/category merges to ONE finding" 1 "$nboth"

merged_block="$(printf '%s\n' "$out" | grep -A 30 'BOTHFLAGGED')"
assert_contains "merged finding lists codex source" "$merged_block" '"codex"'
assert_contains "merged finding lists kimi source"  "$merged_block" '"kimi"'
assert_contains "merged finding has agreement true" "$merged_block" '"agreement": true'
assert_contains "merged severity upgraded to most severe" "$merged_block" '"severity": "critical"'
assert_contains "merged unions codex lesson" "$merged_block" 'LESSON_CODEX'
assert_contains "merged unions kimi lesson"  "$merged_block" 'LESSON_KIMI'

# --- 2. near-miss (5 lines apart) stays separate ----------------------------
echo "near-miss stays separate"
assert_contains "keeps codex near-miss finding" "$out" 'NEARMISS unchecked'
assert_contains "keeps kimi near-miss finding"  "$out" 'NEARMISS_FAR'
nfar="$(printf '%s\n' "$out" | grep -c '"agreement": true')"
assert_eq "only the both-flagged finding has agreement" 1 "$nfar"

# --- 3. cross-category same line stays separate -----------------------------
echo "cross-category same line stays separate"
assert_contains "keeps correctness finding at c.js:7" "$out" 'XCAT_CORRECTNESS'
assert_contains "keeps test-gap finding at c.js:7"    "$out" 'XCAT_TESTGAP'

# --- 4. deterministic ordering: severity rank then file ---------------------
echo "ordering"
pos_aearly="$(printf '%s\n' "$out" | grep -n 'AEARLY'           | head -1 | cut -d: -f1)"
pos_both="$(printf '%s\n' "$out"   | grep -n 'BOTHFLAGGED'      | head -1 | cut -d: -f1)"
pos_near="$(printf '%s\n' "$out"   | grep -n 'NEARMISS unchecked' | head -1 | cut -d: -f1)"
pos_zlow="$(printf '%s\n' "$out"   | grep -n 'ZLOW'             | head -1 | cut -d: -f1)"
if [ -n "$pos_both" ] && [ -n "$pos_aearly" ] && [ "$pos_both" -lt "$pos_aearly" ]; then
  pass "within critical, files sort alphabetically (src/a.js before src/api.js)"
else
  fail "within-severity file ordering (BOTHFLAGGED before AEARLY)"
fi
if [ -n "$pos_aearly" ] && [ -n "$pos_near" ] && [ "$pos_aearly" -lt "$pos_near" ]; then
  pass "critical sorts before high"
else
  fail "critical sorts before high"
fi
if [ -n "$pos_near" ] && [ -n "$pos_zlow" ] && [ "$pos_near" -lt "$pos_zlow" ]; then
  pass "high sorts before low"
else
  fail "high sorts before low"
fi

out2="$(node "$SUT" "codex:$DIR/codex.json" "kimi:$DIR/kimi.json" 2>/dev/null)"
assert_eq "identical run is byte-identical (deterministic)" "$out" "$out2"

# within-severity file ordering: both criticals — src/a.js before src/api.js
first_crit_file="$(printf '%s\n' "$out" | grep '"file"' | head -1)"
assert_contains "within critical, src/a.js sorts before src/api.js" "$first_crit_file" 'src/a.js'

# --- 5. coverage notes pass through backend-tagged --------------------------
echo "coverage notes"
assert_contains "coverage note kept"          "$out" 'COVERAGE_CODEX'
cov_block="$(printf '%s\n' "$out" | grep -B 2 'COVERAGE_CODEX')"
assert_contains "coverage note backend-tagged" "$cov_block" '"codex"'

# --- 6. malformed input = fail loud -----------------------------------------
echo "malformed input"
stdout="$(node "$SUT" "codex:$DIR/codex.json" "kimi:$DIR/broken.json" 2>/dev/null)"; rc=$?
if [ "$rc" -ne 0 ]; then pass "malformed JSON exits nonzero"; else fail "malformed JSON exits nonzero (got 0)"; fi
assert_eq "malformed JSON emits no stdout" "" "$stdout"
err="$(node "$SUT" "codex:$DIR/codex.json" "kimi:$DIR/broken.json" 2>&1 >/dev/null)"
assert_contains "malformed JSON names the file on stderr"    "$err" "broken.json"
assert_contains "malformed JSON names the backend on stderr" "$err" "kimi"

stdout="$(node "$SUT" "codex:$DIR/nofindings.json" 2>/dev/null)"; rc=$?
if [ "$rc" -ne 0 ]; then pass "missing findings array exits nonzero"; else fail "missing findings array exits nonzero (got 0)"; fi
err="$(node "$SUT" "codex:$DIR/nofindings.json" 2>&1 >/dev/null)"
assert_contains "missing findings array reported on stderr" "$err" '"findings" array'

err="$(node "$SUT" "codex:$DIR/does-not-exist.json" 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -ne 0 ]; then pass "unreadable path exits nonzero"; else fail "unreadable path exits nonzero (got 0)"; fi
assert_contains "unreadable path reported on stderr" "$err" "cannot read"

err="$(node "$SUT" "no-colon-arg" 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -ne 0 ]; then pass "untagged arg exits nonzero"; else fail "untagged arg exits nonzero (got 0)"; fi
assert_contains "untagged arg explains the form" "$err" "<backend>:<path>"

err="$(node "$SUT" 2>&1 >/dev/null)"; rc=$?
if [ "$rc" -ne 0 ]; then pass "no args exits nonzero"; else fail "no args exits nonzero (got 0)"; fi
assert_contains "no args prints usage" "$err" "usage:"

# --- summary ----------------------------------------------------------------
echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
