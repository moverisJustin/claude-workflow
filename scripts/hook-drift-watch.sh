#!/usr/bin/env bash
# hook-drift-watch.sh — Post-commit drift check (silent on healthy scores)
# Wired as a PostToolUse hook on Bash in settings.json, with an
# `"if": "Bash(git commit*)"` filter. The script ALSO self-filters on the
# command from the stdin payload, so it stays correct on Claude Code
# versions that ignore the `if` field.
#
# Output contract: PostToolUse plain stdout does NOT reach Claude's context;
# findings are emitted as JSON hookSpecificOutput.additionalContext.

set -uo pipefail

THRESHOLD=80
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

PAYLOAD=$(cat 2>/dev/null || true)
[ -z "$PAYLOAD" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Self-filter: only act on git commit commands
IS_COMMIT=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, re, sys
try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    print("yes" if re.search(r"\bgit\s+(?:-C\s+\S+\s+)?commit\b", cmd) else "no", end="")
except Exception:
    print("no", end="")
' 2>/dev/null) || IS_COMMIT="no"
[ "$IS_COMMIT" = "yes" ] || exit 0

# Find drift-check.sh — project-local first, then alongside this script, then global
DRIFT_SCRIPT=""
if [ -f "$PROJECT_DIR/.claude/scripts/drift-check.sh" ]; then
  DRIFT_SCRIPT="$PROJECT_DIR/.claude/scripts/drift-check.sh"
elif [ -f "$SCRIPT_DIR/drift-check.sh" ]; then
  DRIFT_SCRIPT="$SCRIPT_DIR/drift-check.sh"
elif [ -f "$HOME/.claude/scripts/drift-check.sh" ]; then
  DRIFT_SCRIPT="$HOME/.claude/scripts/drift-check.sh"
fi
[ -z "$DRIFT_SCRIPT" ] && exit 0

# No Memory Bank — skip silently
[ -d "$PROJECT_DIR/.claude/memory" ] || exit 0

OUTPUT=$(cd "$PROJECT_DIR" && bash "$DRIFT_SCRIPT" --quiet 2>/dev/null) || OUTPUT="[DRIFT] Score: 100/100"
SCORE=$(echo "$OUTPUT" | grep -oE 'Score: [0-9]+' | grep -oE '[0-9]+' || true)

if [ -n "$SCORE" ] && [ "$SCORE" -lt "$THRESHOLD" ]; then
  MSG="$OUTPUT — Memory Bank drift detected after this commit. Run /drift-check for details and auto-fix." \
  python3 -c '
import json, os
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": os.environ["MSG"],
}}))
' 2>/dev/null || true
fi

exit 0
