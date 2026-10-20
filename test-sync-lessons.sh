#!/usr/bin/env bash
set -uo pipefail

# Guard test for sync-lessons.sh opt-in promotion.
# Proves a private (untagged) global pattern is NOT written into the repo CLAUDE.md,
# while a "<!-- shareable -->"-tagged pattern IS, Repo->Local still works, and
# dedup-by-heading is preserved. Pure bash, no deps. Exits non-zero on any failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC="$SCRIPT_DIR/sync-lessons.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LOCAL="$TMP/local.md"   # stand-in for the private ~/.claude/CLAUDE.md (superset)
REPO="$TMP/repo.md"     # stand-in for the public repo CLAUDE.md (curated subset)

# Quoted heredoc: backticks and the HTML-comment marker are written literally.
cat > "$LOCAL" <<'EOF'
# Intro

Preamble.

# Learned Patterns

### Existing shared pattern
Already present in both files.

### Shareable new pattern
<!-- shareable -->
A universal lesson explicitly opted in to the public repo.

### fly secrets private pattern
`fly secrets set` does NOT rebuild the image. Private, untagged -- must NOT leak.

# Trailing Section

end.
EOF

cat > "$REPO" <<'EOF'
# Intro

Preamble.

# Learned Patterns

### Existing shared pattern
Already present in both files.

### Repo-only shared pattern
Lives only in the repo; should flow down to local.

### Repo-only fenced pattern
A lesson whose example contains a column-0 comment inside a code fence:
```bash
# nightly comment inside fence
echo hi
```

# Trailing Section

end.
EOF

echo "=== test-sync-lessons.sh ==="
LOCAL_FILE="$LOCAL" REPO_FILE="$REPO" bash "$SYNC" > "$TMP/out.log" 2>&1 || {
  echo "FAIL: sync-lessons.sh exited non-zero"; cat "$TMP/out.log"; exit 1;
}

pass=0
fail=0

assert_contains() { # file pattern desc
  if grep -qF -- "$2" "$1"; then
    echo "  PASS: $3"; pass=$((pass + 1))
  else
    echo "  FAIL: $3 (expected to find: $2)"; fail=$((fail + 1))
  fi
}

assert_absent() { # file pattern desc
  if grep -qF -- "$2" "$1"; then
    echo "  FAIL: $3 (unexpectedly found: $2)"; fail=$((fail + 1))
  else
    echo "  PASS: $3"; pass=$((pass + 1))
  fi
}

assert_count() { # file pattern expected desc
  local n
  n=$(grep -cF -- "$2" "$1" || true)
  if [ "$n" -eq "$3" ]; then
    echo "  PASS: $4 (count=$n)"; pass=$((pass + 1))
  else
    echo "  FAIL: $4 (count=$n, expected $3)"; fail=$((fail + 1))
  fi
}

# Core guard: a private, untagged pattern is NOT promoted to the repo.
assert_absent   "$REPO"  "### fly secrets private pattern" "private untagged pattern NOT promoted to repo"
# A shareable-tagged pattern IS promoted to the repo.
assert_contains "$REPO"  "### Shareable new pattern"       "shareable-tagged pattern promoted to repo"
# Repo -> Local still works.
assert_contains "$LOCAL" "### Repo-only shared pattern"    "repo-only pattern pulled down to local"
# Dedup-by-heading preserved (no duplicate of the common pattern).
assert_count    "$REPO"  "### Existing shared pattern" 1   "existing pattern not duplicated in repo"
# The private pattern is reported as held back (transparency).
assert_contains "$TMP/out.log" "Kept local" "held-back private pattern reported to user"

# --- Placement: inserted lessons must land INSIDE the Learned Patterns section ---
# (an EOF append after "# Trailing Section" is invisible to the extractor,
# so dedup breaks and every future sync re-appends the lesson)

assert_before() { # file first_pattern second_pattern desc
  local a b
  a=$(grep -nF -- "$2" "$1" | head -1 | cut -d: -f1)
  b=$(grep -nF -- "$3" "$1" | head -1 | cut -d: -f1)
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then
    echo "  PASS: $4 (line $a < $b)"; pass=$((pass + 1))
  else
    echo "  FAIL: $4 (lines: '$2'=$a, '$3'=$b)"; fail=$((fail + 1))
  fi
}

assert_before "$REPO"  "### Shareable new pattern"    "# Trailing Section" "promoted lesson placed inside repo Learned Patterns section"
assert_before "$LOCAL" "### Repo-only shared pattern" "# Trailing Section" "pulled lesson placed inside local Learned Patterns section"

# Fence-awareness: a column-0 "# comment" inside a code fence is NOT a section
# boundary — the promoted lesson must land AFTER the fenced lesson, never
# spliced into the middle of its code block.
assert_before "$REPO" "# nightly comment inside fence" "### Shareable new pattern" "insertion not spliced into a code fence"
assert_contains "$LOCAL" "### Repo-only fenced pattern" "fenced lesson pulled down to local intact"

# --- Idempotency: a second run must not duplicate anything ---
LOCAL_FILE="$LOCAL" REPO_FILE="$REPO" bash "$SYNC" > "$TMP/out2.log" 2>&1 || {
  echo "  FAIL: second sync run exited non-zero"; fail=$((fail + 1));
}
assert_count "$REPO"  "### Shareable new pattern" 1    "second run does not re-append promoted lesson"
assert_count "$LOCAL" "### Repo-only shared pattern" 1 "second run does not re-append pulled lesson"
assert_count "$REPO"  "### Existing shared pattern" 1  "second run preserves dedup of existing pattern"
assert_count "$LOCAL" "### Repo-only fenced pattern" 1 "second run does not re-append fenced lesson"

# --- Symlink preservation: ~/.claude/CLAUDE.md symlinked into a dotfiles repo
# must stay a symlink (the insert path must rewrite in place, not mv over it) ---
SYM_REAL="$TMP/dotfiles-claude.md"
SYM_LINK="$TMP/sym-local.md"
cat > "$SYM_REAL" <<'EOF'
# Intro

# Learned Patterns

### Existing shared pattern
Already present in both files.

# Trailing Section

end.
EOF
ln -s "$SYM_REAL" "$SYM_LINK"
LOCAL_FILE="$SYM_LINK" REPO_FILE="$REPO" bash "$SYNC" > "$TMP/out3.log" 2>&1 || {
  echo "  FAIL: symlink sync run exited non-zero"; fail=$((fail + 1));
}
if [ -L "$SYM_LINK" ]; then
  echo "  PASS: symlinked local file stays a symlink after insert"; pass=$((pass + 1))
else
  echo "  FAIL: insert replaced the symlink with a regular file"; fail=$((fail + 1))
fi
assert_contains "$SYM_REAL" "### Repo-only shared pattern" "lesson written through the symlink to the dotfiles copy"

# --- Empty-section tolerance: a lessons file with a heading but ZERO lessons
# must be a no-op sync target, not a set -e/pipefail crash (this exact crash
# once made the installer's migration silently lose every lesson) ---
EMPTY="$TMP/empty-local.md"
printf '# Learned Patterns\n' > "$EMPTY"
if LOCAL_FILE="$EMPTY" REPO_FILE="$REPO" bash "$SYNC" > "$TMP/out4.log" 2>&1; then
  echo "  PASS: heading-only local file: sync exits 0"; pass=$((pass + 1))
else
  echo "  FAIL: heading-only local file crashed the sync"; fail=$((fail + 1))
fi
assert_contains "$EMPTY" "### Repo-only shared pattern" "repo lessons flow into an initially empty local file"

# --- Large corpus: text past the pipe buffer must sync, not die of SIGPIPE ---
# `echo "$big" | awk '... exit'` and `echo "$big" | grep -q` stop reading
# early. Once the text outgrows the pipe buffer (64KB plus what the reader has
# buffered), echo takes SIGPIPE and pipefail turns the pipeline into exit 141:
# set -e kills the sync, and an `if !` test reads a present title as missing.
# The real corpus passed 130KB, and every install ended in "lesson sync
# failed". The fixtures run to ~300KB so the failure is certain, not a race.

# big_lessons PREFIX COUNT BODY_LINES TITLE_PAD MARKER: COUNT lessons titled
# "### PREFIX <n>" plus TITLE_PAD bytes of padding, each with MARKER (if set)
# and BODY_LINES 100-byte body lines.
big_lessons() {
  awk -v p="$1" -v n="$2" -v lines="$3" -v tpad="$4" -v marker="$5" 'BEGIN {
    body = "Filler that pushes the lessons section past the pipe buffer, one line at a time. ..................."
    pad = ""
    for (k = 0; k < tpad; k++) pad = pad "x"
    for (i = 1; i <= n; i++) {
      print "### " p " " i (tpad > 0 ? " " pad : "")
      if (marker != "") print marker
      for (j = 0; j < lines; j++) print body
      print ""
    }
  }'
}

# (a) A new lesson ahead of ~300KB of corpus: the block extractor stops at the
# next heading with the rest unread. This is the crash install.sh hit.
BIG_A_LOCAL="$TMP/big-a-local.md"
BIG_A_REPO="$TMP/big-a-repo.md"
{
  printf '# Learned Patterns\n\n### Shareable lesson ahead of a large corpus\n<!-- shareable -->\nNew, and first in the section.\n\n'
  big_lessons "Large private pattern" 1 3000 0 ""
} > "$BIG_A_LOCAL"
printf '# Learned Patterns\n' > "$BIG_A_REPO"
if LOCAL_FILE="$BIG_A_LOCAL" REPO_FILE="$BIG_A_REPO" bash "$SYNC" > "$TMP/out5.log" 2>&1; then
  echo "  PASS: ~300KB local section: sync exits 0"; pass=$((pass + 1))
else
  echo "  FAIL: ~300KB local section crashed the sync (exit $?)"; fail=$((fail + 1))
fi
assert_contains "$BIG_A_REPO" "### Shareable lesson ahead of a large corpus" "lesson ahead of a large corpus promoted to repo"
assert_absent   "$BIG_A_REPO" "### Large private pattern 1" "large untagged lesson kept local"

# (b) One shareable lesson over 64KB: the marker check stops at the marker.
# Before the fix this did not crash: it held the lesson back without a word.
BIG_B_LOCAL="$TMP/big-b-local.md"
BIG_B_REPO="$TMP/big-b-repo.md"
{ printf '# Learned Patterns\n\n'; big_lessons "Large shareable pattern" 1 3000 0 "<!-- shareable -->"; } > "$BIG_B_LOCAL"
printf '# Learned Patterns\n' > "$BIG_B_REPO"
LOCAL_FILE="$BIG_B_LOCAL" REPO_FILE="$BIG_B_REPO" bash "$SYNC" > "$TMP/out6.log" 2>&1 || {
  echo "  FAIL: large shareable lesson sync exited non-zero"; fail=$((fail + 1));
}
assert_contains "$BIG_B_REPO" "### Large shareable pattern 1" "shareable lesson over 64KB promoted to repo"

# (c) Title lists over 64KB in both files: the dedup check stops at the first
# match. 1KB headings keep the lesson count, and so the run time, low. Every
# lesson is shareable and already in both files, so a title misread as missing
# shows up as a duplicate.
BIG_C_LOCAL="$TMP/big-c-local.md"
BIG_C_REPO="$TMP/big-c-repo.md"
{ printf '# Learned Patterns\n\n'; big_lessons "Long-title pattern" 300 1 1000 "<!-- shareable -->"; } > "$BIG_C_LOCAL"
cp "$BIG_C_LOCAL" "$BIG_C_REPO"
BIG_C_TITLE="$(grep -m1 '^### Long-title pattern 1 ' "$BIG_C_LOCAL")"
if LOCAL_FILE="$BIG_C_LOCAL" REPO_FILE="$BIG_C_REPO" bash "$SYNC" > "$TMP/out7.log" 2>&1; then
  echo "  PASS: ~300KB title lists: sync exits 0"; pass=$((pass + 1))
else
  echo "  FAIL: ~300KB title lists crashed the sync (exit $?)"; fail=$((fail + 1))
fi
assert_count "$BIG_C_REPO"  "$BIG_C_TITLE" 1 "present title not re-promoted when the repo title list is over 64KB"
assert_count "$BIG_C_LOCAL" "$BIG_C_TITLE" 1 "present title not re-pulled when the local title list is over 64KB"

echo ""
echo "Passed: $pass  Failed: $fail"
if [ "$fail" -ne 0 ]; then
  echo "--- sync output ---"
  cat "$TMP/out.log"
  exit 1
fi
echo "All assertions passed."
