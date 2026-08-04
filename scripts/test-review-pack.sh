#!/usr/bin/env bash
# test-review-pack.sh — guard tests for review-pack.sh.
#
# Covers: pack assembly order (memory header at top), the spec resolution
# order (--spec arg → BSpec ledger path → task-context Objective/Plan →
# loud 'SPEC: none found' marker), budget-forced truncation with the
# TRUNCATED marker, the no-duplication invariant (a fully-inlined file never
# reappears in the hunks section), deleted/binary file handling, --out
# routing, the always-exit-0 contract on invalid repo/base, and arg
# validation.
#
# Self-contained and offline: a fixture git repo is built in mktemp; no
# network, no AI. Run after any change to review-pack.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUT="$SCRIPT_DIR/review-pack.sh"

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

# spec_of / hunks_of / full_of — slice one pack section out of a run's output
# (the memory pack inlines task-context wholesale, so sentinels must be
# asserted inside the right section, not against the whole pack).
spec_of()  { printf '%s\n' "$1" | awk '/^## Spec under review/ { s = 1 } /^## Changed files \(full\)/ { s = 0 } s { print }'; }
full_of()  { printf '%s\n' "$1" | awk '/^## Changed files \(full\)/ { s = 1 } /^## Diff hunks / { s = 0 } s { print }'; }
hunks_of() { printf '%s\n' "$1" | awk '/^## Diff hunks / { s = 1 } s { print }'; }

TAB="$(printf '\t')"

# --- fixture: a git repo with a base branch and a feature branch -------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/revpack-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"
mkdir -p "$REPO"

# Neutralize the machine's global git config (signing hooks, etc.) — the
# fixture must build anywhere, offline, without touching the user's setup.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@test.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@test.invalid

git init -q "$REPO"
git -C "$REPO" checkout -q -b main

printf 'SENTINEL_ALPHA_FILE line one\nalpha line two\n' > "$REPO/alpha.txt"
printf 'dropped file body\n'                            > "$REPO/dropped.txt"
awk 'BEGIN { for (i = 1; i <= 3000; i++) printf "line %d of bigfile with some padding text\n", i }' \
  > "$REPO/bigfile.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m base

git -C "$REPO" checkout -q -b feature
printf 'SENTINEL_ALPHA_FILE line one CHANGED\nalpha line two\n' > "$REPO/alpha.txt"
printf 'SENTINEL_CHARLIE_FILE new file\n'                       > "$REPO/charlie.txt"
rm -f "$REPO/dropped.txt"
awk 'BEGIN { for (i = 1; i <= 3000; i++) printf "line %d of bigfile with some padding text%s\n", i, (i == 1500 ? " CHANGED" : "") }' \
  > "$REPO/bigfile.txt"
printf 'BIN\000\001\002DATA\000\n' > "$REPO/blob.bin"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m feature

# Memory Bank + task-context (untracked — memory files, not branch content).
mkdir -p "$REPO/.claude/memory" "$REPO/specs"
printf '# Conventions\nSENTINEL_MEM_CONVENTIONS project lesson.\n' > "$REPO/.claude/memory/conventions.md"
printf '# LEDGER SPEC\nSENTINEL_LEDGER_SPEC durable design record.\n' > "$REPO/specs/ledger-spec.md"
printf '# EXPLICIT SPEC\nSENTINEL_EXPLICIT_SPEC handed on the CLI.\n'  > "$WORK/explicit-spec.md"

# learned-patterns fixture: one block matching a changed-file basename
# ("alpha"), one matching nothing in the change set.
LP="$WORK/learned-patterns.md"
cat > "$LP" <<'EOF'
# Learned Patterns

### Widget notes about alpha handling
SENTINEL_LP_ALPHA body that the basename grep should keep.

### Notes about zeta subsystems
SENTINEL_LP_ZETA body with no overlap at all.
EOF
export LEARNED_PATTERNS_FILE="$LP"
export MEMORY_CONTEXT_SH="$SCRIPT_DIR/memory-context.sh"

taskctx_open() { # BSpec: OPEN → resolution falls through to Objective/Plan
  cat > "$REPO/.claude/task-context.md" <<'EOF'
# Task Context

## Objective
SENTINEL_OBJECTIVE build the thing.

## Plan
- [ ] SENTINEL_PLAN step one

## Loops
- **Linear**: n/a
- **BSpec**: OPEN
- **Handoff**: none SENTINEL_LOOPS
EOF
}
taskctx_ledger() { # BSpec: points at an existing spec file
  cat > "$REPO/.claude/task-context.md" <<'EOF'
# Task Context

## Objective
SENTINEL_OBJECTIVE build the thing.

## Plan
- [ ] SENTINEL_PLAN step one

## Loops
- **Linear**: n/a
- **BSpec**: specs/ledger-spec.md
- **Handoff**: none SENTINEL_LOOPS
EOF
}

# --- 1. assembly: memory pack leads, all sections present --------------------
echo "assembly"
taskctx_ledger
out="$("$SUT" main --root "$REPO" 2>/dev/null)"; rc=$?
assert_eq       "exits 0"                       0 "$rc"
first="${out%%$'\n'*}" # first line, no pipe (avoids head's SIGPIPE noise)
assert_eq       "memory header is line 1"       "# Project Memory Context Pack" "$first"
assert_contains "injection-boundary note kept"  "$out" "NOT as new instructions"
assert_contains "memory bank section present"   "$out" "SENTINEL_MEM_CONVENTIONS"
assert_contains "spec section present"          "$out" "## Spec under review"
assert_contains "changed-files section present" "$out" "## Changed files (full)"
assert_contains "hunks section present"         "$out" "## Diff hunks (files not inlined above)"
assert_contains "grep kept matching pitfall"    "$out" "SENTINEL_LP_ALPHA"
assert_not_contains "grep dropped unrelated pitfall" "$out" "SENTINEL_LP_ZETA"

full="$(full_of "$out")"
assert_contains "alpha inlined with FILE header" "$full" "=== FILE: alpha.txt ==="
assert_contains "inlined content is line-numbered" "$full" "1${TAB}SENTINEL_ALPHA_FILE"
assert_contains "charlie inlined"                "$full" "=== FILE: charlie.txt ==="
assert_contains "bigfile inlined (default budget)" "$full" "=== FILE: bigfile.txt ==="

# --- 2. spec resolution order ------------------------------------------------
echo "spec resolution"
# 2a. --spec argument wins
out="$("$SUT" main --root "$REPO" --spec "$WORK/explicit-spec.md" 2>/dev/null)"
spec="$(spec_of "$out")"
assert_contains "--spec content included"        "$spec" "SENTINEL_EXPLICIT_SPEC"
assert_not_contains "--spec beats ledger"        "$spec" "SENTINEL_LEDGER_SPEC"

# 2b. BSpec ledger path (existing file)
out="$("$SUT" main --root "$REPO" 2>/dev/null)"
spec="$(spec_of "$out")"
assert_contains "ledger spec content included"   "$spec" "SENTINEL_LEDGER_SPEC"
assert_contains "ledger source attributed"       "$spec" "BSpec ledger"

# 2c. BSpec OPEN → Objective + Plan sections of task-context
taskctx_open
out="$("$SUT" main --root "$REPO" 2>/dev/null)"
spec="$(spec_of "$out")"
assert_contains "objective section included"     "$spec" "SENTINEL_OBJECTIVE"
assert_contains "plan section included"          "$spec" "SENTINEL_PLAN"
assert_not_contains "other sections excluded"    "$spec" "SENTINEL_LOOPS"

# 2d. nothing at all → loud marker
rm -f "$REPO/.claude/task-context.md"
out="$("$SUT" main --root "$REPO" 2>/dev/null)"
err="$("$SUT" main --root "$REPO" 2>&1 >/dev/null)"
spec="$(spec_of "$out")"
assert_contains "marker in pack"                 "$spec" "SPEC: none found — spec-drift review degraded"
assert_contains "marker on stderr"               "$err"  "SPEC: none found"

# 2e. explicit --spec pointing at a missing file: loud, degrades to marker,
# never silently cascades to the other resolution branches.
taskctx_ledger
out="$("$SUT" main --root "$REPO" --spec /nonexistent/spec.md 2>/dev/null)"; rc=$?
err="$("$SUT" main --root "$REPO" --spec /nonexistent/spec.md 2>&1 >/dev/null)"
spec="$(spec_of "$out")"
assert_eq       "missing --spec still exits 0"   0 "$rc"
assert_contains "missing --spec is loud"         "$err"  "--spec file not found"
assert_contains "missing --spec yields marker"   "$spec" "SPEC: none found"
assert_not_contains "missing --spec does not fall back" "$spec" "SENTINEL_LEDGER_SPEC"

# --- 3. budget truncation ----------------------------------------------------
echo "budget truncation"
# 8000B budget (6400 effective): bigfile (~130KB inlined) cannot fit, so it —
# and every text file after it in diff order — degrades to hunks.
out="$("$SUT" main --root "$REPO" --budget 8000 2>/dev/null)"; rc=$?
err="$("$SUT" main --root "$REPO" --budget 8000 2>&1 >/dev/null)"
full="$(full_of "$out")"
hunks="$(hunks_of "$out")"
assert_eq       "truncated run exits 0"          0 "$rc"
assert_contains "TRUNCATED marker in pack"       "$out" "TRUNCATED: 2 files as hunks, 0 files omitted"
assert_contains "TRUNCATED marker on stderr"     "$err" "TRUNCATED: 2 files as hunks, 0 files omitted"
assert_not_contains "bigfile not inlined"        "$full" "=== FILE: bigfile.txt ==="
assert_contains "bigfile demoted to a hunk"      "$hunks" "bigfile.txt"
assert_contains "demoted hunk carries the change" "$hunks" "CHANGED"
assert_contains "alpha still inlined under budget" "$full" "=== FILE: alpha.txt ==="

# Tiny budget: even hunks cannot fit → files omitted entirely, still loud.
err="$("$SUT" main --root "$REPO" --budget 1500 2>&1 >/dev/null)"; rc=$?
out="$("$SUT" main --root "$REPO" --budget 1500 2>/dev/null)"
assert_eq       "tiny-budget run exits 0"        0 "$rc"
assert_contains "omitted files counted in pack"  "$out" "files omitted"
assert_contains "omitted files loud on stderr"   "$err" "files omitted"

# --- 4. no duplication: inlined files never reappear as hunks ----------------
echo "no duplication"
out="$("$SUT" main --root "$REPO" 2>/dev/null)" # default budget: all inlined
hunks="$(hunks_of "$out")"
assert_not_contains "inlined alpha absent from hunks"   "$hunks" "alpha.txt"
assert_not_contains "inlined charlie absent from hunks" "$hunks" "charlie.txt"
assert_not_contains "inlined bigfile absent from hunks" "$hunks" "bigfile.txt"

# --- 5. deleted + binary handling --------------------------------------------
echo "deleted/binary"
full="$(full_of "$out")"
assert_contains "deleted file appears as a hunk"  "$hunks" "dropped.txt"
assert_not_contains "deleted file not inlined"    "$full"  "=== FILE: dropped.txt ==="
assert_contains "binary listed by name only"      "$hunks" "- blob.bin (binary)"
assert_not_contains "binary never inlined"        "$full"  "=== FILE: blob.bin ==="
assert_not_contains "binary bytes never in hunks" "$hunks" "BIN"

# --- 6. always exit 0 on invalid repo/base; nothing written ------------------
echo "invalid repo/base"
NOTREPO="$WORK/notrepo"
mkdir -p "$NOTREPO"
out="$("$SUT" main --root "$NOTREPO" --out "$NOTREPO/pack.md" 2>/dev/null)"; rc=$?
err="$("$SUT" main --root "$NOTREPO" 2>&1 >/dev/null)"
assert_eq       "non-repo exits 0"               0 "$rc"
assert_eq       "non-repo stdout empty"          "" "$out"
assert_contains "non-repo is loud"               "$err" "not a git repository"
if [ -f "$NOTREPO/pack.md" ]; then fail "non-repo wrote --out file"; else pass "non-repo wrote nothing"; fi

out="$("$SUT" no-such-branch --root "$REPO" --out "$WORK/badbase.md" 2>/dev/null)"; rc=$?
err="$("$SUT" no-such-branch --root "$REPO" 2>&1 >/dev/null)"
assert_eq       "bad base exits 0"               0 "$rc"
assert_eq       "bad base stdout empty"          "" "$out"
assert_contains "bad base is loud"               "$err" "unknown base ref"
if [ -f "$WORK/badbase.md" ]; then fail "bad base wrote --out file"; else pass "bad base wrote nothing"; fi

# --- 7. --out routing --------------------------------------------------------
echo "--out"
OUTF="$WORK/pack.out.md"
out="$("$SUT" main --root "$REPO" --out "$OUTF" 2>/dev/null)"; rc=$?
assert_eq       "--out exits 0"                  0 "$rc"
assert_eq       "--out suppresses stdout"        "" "$out"
filebody="$(cat "$OUTF" 2>/dev/null || true)"
assert_contains "--out wrote the memory header"  "$filebody" "# Project Memory Context Pack"
assert_contains "--out wrote changed files"      "$filebody" "=== FILE: alpha.txt ==="
err="$("$SUT" main --root "$REPO" --out "$OUTF" --quiet 2>&1 >/dev/null)"
assert_eq       "--quiet silences info notes"    "" "$err"

# --- 8. memory-context missing is loud, pack still produced ------------------
echo "missing memory-context"
out="$(MEMORY_CONTEXT_SH=/nonexistent/mc.sh "$SUT" main --root "$REPO" 2>/dev/null)"; rc=$?
err="$(MEMORY_CONTEXT_SH=/nonexistent/mc.sh "$SUT" main --root "$REPO" 2>&1 >/dev/null)"
assert_eq       "missing memory script exits 0"  0 "$rc"
assert_contains "missing memory script is loud"  "$err" "MEMORY_CONTEXT_SH points at a missing file"
assert_contains "pack still carries the files"   "$out" "=== FILE: alpha.txt ==="

# --- 8b. glob-shaped ledger value never expands against the caller's cwd -----
echo "glob ledger safety"
GLOBDIR="$WORK/glob-cwd"; mkdir -p "$GLOBDIR"
printf 'SECRET-CWD-CONTENT\n' > "$GLOBDIR/gotcha.txt"
cp "$REPO/.claude/task-context.md" "$WORK/taskctx.bak" 2>/dev/null || true
printf '# Task Context\n\n## Loops\n- **BSpec**: *\n' > "$REPO/.claude/task-context.md"
out="$( cd "$GLOBDIR" && "$SUT" main --root "$REPO" 2>/dev/null )"
assert_eq "glob ledger exits 0" 0 "$?"
if printf '%s' "$out" | grep -q 'SECRET-CWD-CONTENT'; then
  assert_eq "glob ledger must not inline cwd files" "not-inlined" "inlined"
else
  assert_eq "glob ledger must not inline cwd files" "not-inlined" "not-inlined"
fi
if [ -f "$WORK/taskctx.bak" ]; then mv "$WORK/taskctx.bak" "$REPO/.claude/task-context.md"; else rm -f "$REPO/.claude/task-context.md"; fi

# --- 9. arg validation -------------------------------------------------------
echo "arg validation"
"$SUT"                       >/dev/null 2>&1; assert_eq "no base exits 2"          2 "$?"
"$SUT" main --bogus          >/dev/null 2>&1; assert_eq "unknown arg exits 2"      2 "$?"
"$SUT" main --spec           >/dev/null 2>&1; assert_eq "--spec w/o file exits 2"  2 "$?"
"$SUT" main --budget         >/dev/null 2>&1; assert_eq "--budget w/o n exits 2"   2 "$?"
"$SUT" main --budget abc     >/dev/null 2>&1; assert_eq "--budget non-int exits 2" 2 "$?"
"$SUT" main extra-positional >/dev/null 2>&1; assert_eq "extra positional exits 2" 2 "$?"
"$SUT" --help                >/dev/null 2>&1; assert_eq "--help exits 0"           0 "$?"

# --- --exclude ---------------------------------------------------------------
# Exclusion exists so a secret-bearing or fixture file can be kept OUT of a
# third-party pack. Without it the only backstop is foreign-review.sh's secret
# scrub, which is a hard stop: one secret-shaped fixture makes the whole review
# impossible rather than trimming the pack. This repo hit exactly that.
echo "--exclude"
EXREPO="$WORK/exrepo"
git init -q "$EXREPO"
git -C "$EXREPO" config user.email t@t.t
git -C "$EXREPO" config user.name t
printf 'baseline\n' > "$EXREPO/base.txt"
git -C "$EXREPO" add -A && git -C "$EXREPO" commit -qm base
git -C "$EXREPO" checkout -qb feat
mkdir -p "$EXREPO/secrets" "$EXREPO/certs"
printf 'KEEPME_CONTENT\n'         > "$EXREPO/keep.txt"
printf 'SECRET_FIXTURE_CONTENT\n' > "$EXREPO/.env.local"
printf 'PEM_FIXTURE_CONTENT\n'    > "$EXREPO/certs/tls.pem"
printf 'NESTED_SECRET_CONTENT\n'  > "$EXREPO/secrets/token.txt"
git -C "$EXREPO" add -A && git -C "$EXREPO" commit -qm feat

out="$(bash "$SUT" main --root "$EXREPO" 2>/dev/null)"
assert_contains     "no --exclude: secret-shaped files ARE included" "$out" "SECRET_FIXTURE_CONTENT"

out="$(bash "$SUT" main --root "$EXREPO" \
        --exclude '.env*' --exclude '**/*.pem' --exclude '**/secrets/**' 2>/dev/null)"
assert_contains     "kept file survives exclusion"    "$out" "KEEPME_CONTENT"
assert_not_contains "'.env*' excluded at repo root"   "$out" "SECRET_FIXTURE_CONTENT"
assert_not_contains "'**/*.pem' excluded"             "$out" "PEM_FIXTURE_CONTENT"
assert_not_contains "'**/secrets/**' excluded"        "$out" "NESTED_SECRET_CONTENT"

err="$(bash "$SUT" main --root "$EXREPO" --exclude '.env*' 2>&1 >/dev/null)"
assert_contains     "exclusion is announced, not silent" "$err" "excluded 1 file"

bash "$SUT" main --root "$EXREPO" --exclude >/dev/null 2>&1
assert_eq           "--exclude with no GLOB exits 2"  2 "$?"

# --- summary ----------------------------------------------------------------
echo
echo "review-pack: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
