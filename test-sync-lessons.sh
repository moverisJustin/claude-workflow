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

echo ""
echo "Passed: $pass  Failed: $fail"
if [ "$fail" -ne 0 ]; then
  echo "--- sync output ---"
  cat "$TMP/out.log"
  exit 1
fi
echo "All assertions passed."
