#!/usr/bin/env bash
set -euo pipefail

# Bidirectional Lesson Sync
# Merges "Learned Patterns" between local ~/.claude/CLAUDE.md and repo CLAUDE.md
# - New local lessons → repo (so they can be pushed to other machines)
# - New repo lessons → local (so pulled lessons take effect)
# - Never overwrites or removes existing lessons
# - Deduplicates by ### heading

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_FILE="$HOME/.claude/CLAUDE.md"
REPO_FILE="$SCRIPT_DIR/CLAUDE.md"

# --- Helpers ---

# Extract the Learned Patterns section from a CLAUDE.md file
# Returns everything from "# Learned Patterns" to the next "# " heading (or EOF)
extract_lessons_section() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo ""
    return
  fi
  # Get content between "# Learned Patterns" and the next top-level heading (or EOF)
  awk '
    /^# Learned Patterns/ { found=1; next }
    found && /^# [^#]/ { exit }
    found { print }
  ' "$file"
}

# Extract individual lesson blocks as: TITLE\nBODY
# Each lesson starts with "### " and continues until the next "### " or EOF
extract_lesson_titles() {
  local section="$1"
  echo "$section" | grep "^### " | sed 's/^### //'
}

# Extract a full lesson block (### title + body) by title
extract_lesson_block() {
  local section="$1"
  local title="$2"
  echo "$section" | awk -v title="### $title" '
    $0 == title { found=1; print; next }
    found && /^### / { exit }
    found { print }
  '
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

# --- Direction 1: Local → Repo (new local lessons that repo doesn't have) ---

if [ -n "$LOCAL_TITLES" ]; then
  while IFS= read -r title; do
    [ -z "$title" ] && continue
    # Check if this title exists in repo
    if ! echo "$REPO_TITLES" | grep -qxF "$title"; then
      # New lesson from local, append to repo
      BLOCK=$(extract_lesson_block "$LOCAL_SECTION" "$title")
      if [ -n "$BLOCK" ]; then
        echo "" >> "$REPO_FILE"
        echo "$BLOCK" >> "$REPO_FILE"
        REPO_ADDED=$((REPO_ADDED + 1))
        echo "  Local → Repo: $title"
      fi
    fi
  done <<< "$LOCAL_TITLES"
fi

# --- Direction 2: Repo → Local (new repo lessons that local doesn't have) ---

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
        echo "" >> "$LOCAL_FILE"
        echo "$BLOCK" >> "$LOCAL_FILE"
        LOCAL_ADDED=$((LOCAL_ADDED + 1))
        echo "  Repo → Local: $title"
      fi
    fi
  done <<< "$REPO_TITLES"
fi

# --- Summary ---

echo ""
if [ $LOCAL_ADDED -eq 0 ] && [ $REPO_ADDED -eq 0 ]; then
  echo "No new lessons to sync. Both files are in sync."
else
  echo "Sync complete:"
  [ $REPO_ADDED -gt 0 ] && echo "  $REPO_ADDED lesson(s) added to repo CLAUDE.md"
  [ $LOCAL_ADDED -gt 0 ] && echo "  $LOCAL_ADDED lesson(s) added to local ~/.claude/CLAUDE.md"
  echo ""
  if [ $REPO_ADDED -gt 0 ]; then
    echo "Don't forget to commit and push the repo changes:"
    echo "  git add CLAUDE.md && git commit -m 'sync lessons' && git push"
  fi
fi
