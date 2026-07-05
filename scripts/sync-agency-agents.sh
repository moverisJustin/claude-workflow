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
# Pinned upstream commit: resyncs are reproducible and cannot silently pull
# changed third-party prompt content. To update: UPSTREAM_PIN=HEAD ./sync-agency-agents.sh,
# review the diff, then move this pin to the new reviewed SHA.
UPSTREAM_PIN="${UPSTREAM_PIN:-217a63b8b6b6ea5752fd436a05996c796ba0ec66}"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: MANIFEST.txt not found at $MANIFEST"
  exit 1
fi

echo "=== Agency-Agents Sync ==="
echo "Upstream: $UPSTREAM_REPO"
echo "Pin: $UPSTREAM_PIN"
echo "Target: $COMMUNITY_DIR"
echo ""

# --- Fetch upstream at the pinned commit ---
echo "--- Fetching upstream repo ---"
git init --quiet "$TEMP_DIR/agency-agents"
git -C "$TEMP_DIR/agency-agents" remote add origin "$UPSTREAM_REPO"
if [ "$UPSTREAM_PIN" = "HEAD" ]; then
  git -C "$TEMP_DIR/agency-agents" fetch --depth 1 --quiet origin HEAD
else
  git -C "$TEMP_DIR/agency-agents" fetch --depth 1 --quiet origin "$UPSTREAM_PIN"
fi
git -C "$TEMP_DIR/agency-agents" checkout --quiet FETCH_HEAD
echo "  Synced at commit: $(git -C "$TEMP_DIR/agency-agents" rev-parse --short HEAD)"
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
echo "Vendored files are kept upstream-faithful (no local model/tools edits) —"
echo "install.sh applies the model tier + read-only tools at DEPLOY time, so a"
echo "resync never clobbers the tiering. See scripts/agent-tier.sh."
echo ""
echo "Next: run install.sh to deploy, or git add agents/community/ to commit"
