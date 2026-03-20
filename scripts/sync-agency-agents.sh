#!/usr/bin/env bash
set -euo pipefail

# Sync selected agents from msitarzewski/agency-agents into agents/community/
# Reads MANIFEST.txt to determine which agents to include.
# Re-runnable: clones fresh each time, replaces community agents.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMUNITY_DIR="$REPO_DIR/agents/community"
MANIFEST="$COMMUNITY_DIR/MANIFEST.txt"
UPSTREAM_REPO="https://github.com/msitarzewski/agency-agents.git"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: MANIFEST.txt not found at $MANIFEST"
  exit 1
fi

echo "=== Agency-Agents Sync ==="
echo "Upstream: $UPSTREAM_REPO"
echo "Target: $COMMUNITY_DIR"
echo ""

# --- Clone upstream ---
echo "--- Cloning upstream repo ---"
git clone --depth 1 --quiet "$UPSTREAM_REPO" "$TEMP_DIR/agency-agents"
echo "  Cloned successfully"
echo ""

# --- Parse manifest ---
SLUGS=()
while IFS= read -r line; do
  # Skip comments and blank lines
  line=$(echo "$line" | sed 's/#.*//' | xargs)
  [ -z "$line" ] && continue
  SLUGS+=("$line")
done < "$MANIFEST"

echo "--- Syncing ${#SLUGS[@]} agents ---"

# --- Remove old community agents (except MANIFEST.txt) ---
find "$COMMUNITY_DIR" -name "*.md" -delete 2>/dev/null || true

# --- Copy selected agents ---
COPIED=0
MISSING=()

for slug in "${SLUGS[@]}"; do
  # Find the file anywhere in the cloned repo (excluding integrations/ and scripts/)
  found=$(find "$TEMP_DIR/agency-agents" \
    -path "*/integrations" -prune -o \
    -path "*/scripts" -prune -o \
    -path "*/strategy" -prune -o \
    -name "${slug}.md" -print | head -1)

  if [ -n "$found" ]; then
    cp "$found" "$COMMUNITY_DIR/${slug}.md"
    COPIED=$((COPIED + 1))
  else
    MISSING+=("$slug")
  fi
done

echo "  Copied: $COPIED agents"

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "  WARNING: ${#MISSING[@]} agents not found in upstream:"
  for m in "${MISSING[@]}"; do
    echo "    - $m"
  done
fi

echo ""
echo "=== Sync Complete ==="
echo "Community agents: $COPIED files in $COMMUNITY_DIR"
echo ""
echo "Next: run install.sh to deploy, or git add agents/community/ to commit"
