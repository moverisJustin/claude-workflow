#!/usr/bin/env bash
# Hook: PreToolUse (Bash, Edit|Write)
# Append-only audit log of commands and file writes.
#
# Contract: hook payload arrives as JSON on stdin. One script serves both
# matchers — it routes on tool_name. Fail-open: never blocks, never errors.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AUDIT_DIR="$PROJECT_DIR/.claude/audit"

PAYLOAD=$(cat 2>/dev/null || true)
[ -z "$PAYLOAD" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

LINE=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    p = json.load(sys.stdin)
    tool = p.get("tool_name", "")
    ti = p.get("tool_input", {})
    if tool == "Bash":
        print("BASH\t" + ti.get("command", "").replace("\n", " "))
    elif tool in ("Edit", "Write"):
        print("FILE_WRITE\t" + ti.get("file_path", ""))
except Exception:
    pass
' 2>/dev/null) || LINE=""
[ -z "$LINE" ] && exit 0

KIND=$(printf '%s' "$LINE" | cut -f1)
DETAIL=$(printf '%s' "$LINE" | cut -f2-)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$AUDIT_DIR" 2>/dev/null || exit 0
# Self-gitignoring: command lines can contain secrets (tokens, connection
# strings) and must never be committable — especially via `git add .claude`,
# which IS routine here because task-context.md is committed by design.
[ -f "$AUDIT_DIR/.gitignore" ] || echo '*' > "$AUDIT_DIR/.gitignore" 2>/dev/null || true
case "$KIND" in
  BASH)       echo "$TS BASH $DETAIL" >> "$AUDIT_DIR/commands.log" 2>/dev/null || true ;;
  FILE_WRITE) echo "$TS FILE_WRITE $DETAIL" >> "$AUDIT_DIR/files.log" 2>/dev/null || true ;;
esac

exit 0
