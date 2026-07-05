#!/usr/bin/env bash
set -euo pipefail

# Bidirectional Lesson Sync
# Merges "Learned Patterns" between local ~/.claude/CLAUDE.md and repo CLAUDE.md
# - Local -> repo: OPT-IN. A local lesson is promoted to the (public) repo ONLY if its
#   block contains the marker "<!-- shareable -->". Untagged lessons stay local, so
#   private / org-specific notes never leak into the public repo. (Default-safe.)
# - Repo -> local: ALL repo lessons are pulled down so shared lessons take effect locally.
# - Never overwrites or removes existing lessons
# - Deduplicates by ### heading
#
# Paths are overridable via the LOCAL_FILE / REPO_FILE env vars (used by test-sync-lessons.sh).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_FILE="${LOCAL_FILE:-$HOME/.claude/CLAUDE.md}"
REPO_FILE="${REPO_FILE:-$SCRIPT_DIR/CLAUDE.md}"

# A local lesson is promoted to the repo only if its block contains this marker.
SHAREABLE_MARKER='<!-- shareable -->'

# --- Helpers ---

# Extract the Learned Patterns section from a CLAUDE.md file
# Returns everything from "# Learned Patterns" to the next "# " heading (or EOF).
# Fence-aware: a "# comment" line inside a ``` code block is lesson content,
# not a section boundary.
extract_lessons_section() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo ""
    return
  fi
  awk '
    /^```/ { fence = !fence }
    !fence && /^# Learned Patterns/ { found=1; next }
    found && !fence && /^# [^#]/ { exit }
    found { print }
  ' "$file"
}

# Extract individual lesson blocks as: TITLE\nBODY
# Each lesson starts with "### " and continues until the next "### " or EOF
extract_lesson_titles() {
  local section="$1"
  echo "$section" | grep "^### " | sed 's/^### //'
}

# Extract a full lesson block (### title + body) by title (fence-aware)
extract_lesson_block() {
  local section="$1"
  local title="$2"
  echo "$section" | awk -v title="### $title" '
    /^```/ { fence = !fence }
    !fence && $0 == title { found=1; print; next }
    found && !fence && /^### / { exit }
    found { print }
  '
}

# Return success if a lesson block opts in to public-repo promotion (contains the marker).
# Keeps private / org-specific lessons local by default.
is_shareable() {
  printf '%s\n' "$1" | grep -qiF "$SHAREABLE_MARKER"
}

# Insert a lesson block INSIDE the "# Learned Patterns" section — before the
# next top-level "# " heading — never at end-of-file. An EOF append lands
# after any trailing section, where extract_lessons_section can't see it, so
# dedup misses it and every future sync re-appends the same lesson forever.
append_lesson() {
  local file="$1" block="$2" insert_before tmp
  if ! grep -q '^# Learned Patterns' "$file"; then
    { echo ""; echo "# Learned Patterns"; } >> "$file"
  fi
  # Line number of the first top-level heading AFTER the section start.
  # Fence-aware: "# comment" inside a ``` code block is not a boundary.
  insert_before=$(awk '
    /^```/ { fence = !fence }
    !fence && /^# Learned Patterns/ { found=1; next }
    found && !fence && /^# [^#]/ { print NR; exit }
  ' "$file")
  if [ -z "$insert_before" ]; then
    # Section runs to EOF — appending is inside the section
    { echo ""; printf '%s\n' "$block"; } >> "$file"
  else
    tmp=$(mktemp)
    head -n $((insert_before - 1)) "$file" > "$tmp"
    printf '%s\n\n' "$block" >> "$tmp"
    tail -n +"$insert_before" "$file" >> "$tmp"
    # cat-over, not mv: preserves the target inode, permissions, and — when
    # the file is a symlink into a dotfiles repo — the symlink itself
    cat "$tmp" > "$file" && rm -f "$tmp"
  fi
}

# --- Main ---

echo "=== Lesson Sync ==="

if [ ! -f "$LOCAL_FILE" ]; then
  echo "No local CLAUDE.md found at $LOCAL_FILE"
  echo "Run install.sh first."
  exit 1
fi

if [ ! -f "$REPO_FILE" ]; then
  echo "No repo CLAUDE.md found at $REPO_FILE"
  exit 1
fi

# Extract lesson sections
LOCAL_SECTION=$(extract_lessons_section "$LOCAL_FILE")
REPO_SECTION=$(extract_lessons_section "$REPO_FILE")

# Get titles from each
LOCAL_TITLES=$(extract_lesson_titles "$LOCAL_SECTION")
REPO_TITLES=$(extract_lesson_titles "$REPO_SECTION")

# Track changes
LOCAL_ADDED=0
REPO_ADDED=0
HELD_BACK=0

# --- Direction 1: Local -> Repo (new local lessons, opt-in via shareable marker) ---

if [ -n "$LOCAL_TITLES" ]; then
  while IFS= read -r title; do
    [ -z "$title" ] && continue
    # Check if this title exists in repo
    if ! echo "$REPO_TITLES" | grep -qxF "$title"; then
      # New lesson from local that the repo doesn't have yet
      BLOCK=$(extract_lesson_block "$LOCAL_SECTION" "$title")
      [ -z "$BLOCK" ] && continue
      # OPT-IN gate: only promote to the public repo if explicitly marked shareable.
      # Untagged lessons stay local so private notes never leak into the public repo.
      if ! is_shareable "$BLOCK"; then
        HELD_BACK=$((HELD_BACK + 1))
        echo "  Kept local (no $SHAREABLE_MARKER marker): $title"
        continue
      fi
      append_lesson "$REPO_FILE" "$BLOCK"
      REPO_ADDED=$((REPO_ADDED + 1))
      echo "  Local -> Repo: $title"
    fi
  done <<< "$LOCAL_TITLES"
fi

# --- Direction 2: Repo -> Local (new repo lessons that local doesn't have) ---

# Re-read repo section after potential additions from direction 1
REPO_SECTION=$(extract_lessons_section "$REPO_FILE")
REPO_TITLES=$(extract_lesson_titles "$REPO_SECTION")

if [ -n "$REPO_TITLES" ]; then
  while IFS= read -r title; do
    [ -z "$title" ] && continue
    # Check if this title exists in local
    if ! echo "$LOCAL_TITLES" | grep -qxF "$title"; then
      # New lesson from repo, append to local
      BLOCK=$(extract_lesson_block "$REPO_SECTION" "$title")
      if [ -n "$BLOCK" ]; then
        append_lesson "$LOCAL_FILE" "$BLOCK"
        LOCAL_ADDED=$((LOCAL_ADDED + 1))
        echo "  Repo -> Local: $title"
      fi
    fi
  done <<< "$REPO_TITLES"
fi

# --- Summary ---

echo ""
if [ $LOCAL_ADDED -eq 0 ] && [ $REPO_ADDED -eq 0 ]; then
  echo "No new lessons synced. Files are in sync."
else
  echo "Sync complete:"
  [ $REPO_ADDED -gt 0 ] && echo "  $REPO_ADDED lesson(s) added to repo CLAUDE.md"
  [ $LOCAL_ADDED -gt 0 ] && echo "  $LOCAL_ADDED lesson(s) added to local ~/.claude/CLAUDE.md"
fi

if [ $HELD_BACK -gt 0 ]; then
  echo ""
  echo "  $HELD_BACK local lesson(s) kept private (no $SHAREABLE_MARKER marker, not promoted to repo)."
  echo "  To publish one, add a line '$SHAREABLE_MARKER' under its ### heading and re-run."
fi

if [ $REPO_ADDED -gt 0 ]; then
  echo ""
  echo "Don't forget to commit and push the repo changes:"
  echo "  git add CLAUDE.md && git commit -m 'sync lessons' && git push"
fi
