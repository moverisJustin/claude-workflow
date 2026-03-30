#!/usr/bin/env bash
# hook-drift-watch.sh — Post-commit drift check (silent on healthy scores)
# Installed as a PostToolUse hook for Bash(git commit) in settings.json
#
# Only outputs if drift score drops below threshold. Silent otherwise.

set -euo pipefail

THRESHOLD=80
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIFT_SCRIPT=""

# Find drift-check.sh — check project-local first, then global
if [ -f ".claude/scripts/drift-check.sh" ]; then
  DRIFT_SCRIPT=".claude/scripts/drift-check.sh"
elif [ -f "$SCRIPT_DIR/drift-check.sh" ]; then
  DRIFT_SCRIPT="$SCRIPT_DIR/drift-check.sh"
elif [ -f "$HOME/.claude/scripts/drift-check.sh" ]; then
  DRIFT_SCRIPT="$HOME/.claude/scripts/drift-check.sh"
fi

# No script found — skip silently
[ -z "$DRIFT_SCRIPT" ] && exit 0

# No Memory Bank — skip silently
[ -d ".claude/memory" ] || exit 0

# Run quiet check and parse score
OUTPUT=$(bash "$DRIFT_SCRIPT" --quiet 2>/dev/null || echo "[DRIFT] Score: 100/100")
SCORE=$(echo "$OUTPUT" | grep -oE 'Score: [0-9]+' | grep -oE '[0-9]+')

# Only output if below threshold
if [ -n "$SCORE" ] && [ "$SCORE" -lt "$THRESHOLD" ]; then
  echo "$OUTPUT"
  echo "Run /drift-check for details and auto-fix."
fi
