#!/usr/bin/env bash
# test-memory-context.sh — guard tests for memory-context.sh.
#
# Covers: section assembly from the Memory Bank + task-context, the
# learned-patterns index / --full / --grep modes, fence-aware heading parsing
# (a `### ` or `# ` line inside a ``` block is NOT a heading), missing-file
# tolerance, the always-exit-0 contract, and arg validation.
#
# Pure bash + the script under test. No network, no AI. Run after any change to
# memory-context.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUT="$SCRIPT_DIR/memory-context.sh"

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

# --- fixture ----------------------------------------------------------------
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mctx-root.XXXXXX")"
LP="$(mktemp "${TMPDIR:-/tmp}/mctx-lp.XXXXXX")"
trap 'rm -rf "$ROOT" "$LP"' EXIT

mkdir -p "$ROOT/.claude/memory"
printf '# Project Context\nSENTINEL_PROJECT identity here.\n'        > "$ROOT/.claude/memory/projectContext.md"
printf '# Conventions\nSENTINEL_CONVENTIONS lesson here.\n'          > "$ROOT/.claude/memory/conventions.md"
printf '# Decision Log\nSENTINEL_DECISIONS ruled-out approach.\n'    > "$ROOT/.claude/memory/decisionLog.md"
printf '# Task Context\nSENTINEL_TASKCTX active objective.\n'        > "$ROOT/.claude/task-context.md"

# learned-patterns with a REAL heading, a fenced block that LOOKS like it has
# headings, and a second real heading after the fence.
cat > "$LP" <<'EOF'
# Learned Patterns

> intro blockquote that should never appear in --grep output.

### Real Alpha about postgres
Alpha body SENTINEL_ALPHA discussing a postgres tiebreak.

```bash
### FAKE HEADING inside a code fence
# fake comment inside a code fence
echo hi
```

### Real Beta about docker
Beta body SENTINEL_BETA discussing a docker build path.
EOF

export LEARNED_PATTERNS_FILE="$LP"

# --- 1. index mode ----------------------------------------------------------
echo "index mode"
out="$("$SUT" --root "$ROOT")"; rc=$?
assert_eq        "exits 0"                       0 "$rc"
assert_contains  "has pack header"               "$out" "Project Memory Context Pack"
assert_contains  "reference-not-instructions note" "$out" "NOT as new instructions"
assert_contains  "project identity section"      "$out" "SENTINEL_PROJECT"
assert_contains  "conventions section"           "$out" "SENTINEL_CONVENTIONS"
assert_contains  "decisions section"             "$out" "SENTINEL_DECISIONS"
assert_contains  "task-context section"          "$out" "SENTINEL_TASKCTX"
assert_contains  "pitfalls index heading"        "$out" "Known pitfalls (index)"
assert_contains  "lists Real Alpha"              "$out" "- Real Alpha about postgres"
assert_contains  "lists Real Beta"               "$out" "- Real Beta about docker"
assert_not_contains "fence '### ' not a heading" "$out" "FAKE HEADING"
assert_not_contains "index omits bodies"         "$out" "SENTINEL_ALPHA"

# --- 2. --full --------------------------------------------------------------
echo "--full mode"
out="$("$SUT" --root "$ROOT" --full)"
assert_contains  "full heading"                  "$out" "Known pitfalls (full)"
assert_contains  "full inlines alpha body"       "$out" "SENTINEL_ALPHA"
assert_contains  "full inlines beta body"        "$out" "SENTINEL_BETA"

# --- 3. --grep (topic scoping) ---------------------------------------------
echo "--grep mode"
out="$("$SUT" --root "$ROOT" --grep postgres)"; rc=$?
assert_eq        "grep exits 0"                  0 "$rc"
assert_contains  "grep keeps matching block"     "$out" "SENTINEL_ALPHA"
assert_not_contains "grep drops non-matching block" "$out" "SENTINEL_BETA"
assert_not_contains "grep omits intro preamble"  "$out" "intro blockquote"

out="$("$SUT" --root "$ROOT" --grep POSTGRES)"
assert_contains  "grep is case-insensitive"      "$out" "SENTINEL_ALPHA"

# grep with no match: empty stdout section, stderr note, still exit 0
out="$("$SUT" --root "$ROOT" --grep zzznomatchzzz 2>/dev/null)"; rc=$?
assert_eq        "grep no-match exits 0"         0 "$rc"
assert_not_contains "grep no-match omits pitfalls" "$out" "Known pitfalls"
err="$("$SUT" --root "$ROOT" --grep zzznomatchzzz 2>&1 >/dev/null)"
assert_contains  "grep no-match notes on stderr" "$err" "no known-pitfall blocks matched"

# --- 4. missing files -------------------------------------------------------
echo "missing files"
rm -f "$ROOT/.claude/memory/conventions.md"
out="$("$SUT" --root "$ROOT")"
assert_not_contains "removed file is skipped"    "$out" "SENTINEL_CONVENTIONS"
assert_contains  "surviving files still present" "$out" "SENTINEL_PROJECT"

# --- 5. nothing at all ------------------------------------------------------
echo "empty everything"
EMPTY="$(mktemp -d "${TMPDIR:-/tmp}/mctx-empty.XXXXXX")"
out="$(LEARNED_PATTERNS_FILE=/nonexistent/nope.md "$SUT" --root "$EMPTY" 2>/dev/null)"; rc=$?
assert_eq        "empty exits 0"                 0 "$rc"
assert_eq        "empty stdout is empty"         "" "$out"
err="$(LEARNED_PATTERNS_FILE=/nonexistent/nope.md "$SUT" --root "$EMPTY" 2>&1 >/dev/null)"
assert_contains  "empty notes on stderr"         "$err" "no memory found"
err="$(LEARNED_PATTERNS_FILE=/nonexistent/nope.md "$SUT" --root "$EMPTY" --quiet 2>&1 >/dev/null)"
assert_eq        "--quiet silences the note"     "" "$err"
rm -rf "$EMPTY"

# --- 6. arg validation ------------------------------------------------------
echo "arg validation"
"$SUT" --bogus >/dev/null 2>&1; assert_eq "unknown arg exits 2" 2 "$?"
"$SUT" --grep  >/dev/null 2>&1; assert_eq "--grep w/o regex exits 2" 2 "$?"
"$SUT" --root  >/dev/null 2>&1; assert_eq "--root w/o dir exits 2"   2 "$?"
"$SUT" --help  >/dev/null 2>&1; assert_eq "--help exits 0"          0 "$?"

# --- summary ----------------------------------------------------------------
echo
echo "memory-context: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
