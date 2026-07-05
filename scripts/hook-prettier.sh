#!/usr/bin/env bash
# Hook: PostToolUse (Edit|Write)
# Auto-format edited files with the project's prettier, if it has one.
#
# Contract: hook payload arrives as JSON on stdin; file path is
# tool_input.file_path. `npx --no-install` means projects without prettier
# are skipped silently instead of triggering a download. Fail-open.

set -uo pipefail

PAYLOAD=$(cat 2>/dev/null || true)
[ -z "$PAYLOAD" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

FILE=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""), end="")
except Exception:
    pass
' 2>/dev/null) || FILE=""
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

case "$FILE" in
  *.js|*.ts|*.jsx|*.tsx|*.json|*.css|*.scss|*.md)
    command -v npx >/dev/null 2>&1 || exit 0
    npx --no-install prettier --write "$FILE" >/dev/null 2>&1 || true
    ;;
esac

exit 0
