#!/usr/bin/env bash
# Hook: Stop
# Enforce the /checks verify gate: if a turn ends while
# .claude/audit/verify-gate is still armed, block the stop and tell Claude
# to finish the checks.
#
# The gate is OPT-IN per run: only the /checks command arms it (and clears
# it when gates pass), so normal turns are never blocked. Escape hatch:
# after MAX_ATTEMPTS blocked stops the gate auto-disarms — a gate that
# cannot pass must trap a human's attention, not the agent forever.
#
# Contract: Stop hooks receive JSON on stdin and answer with a top-level
# {"decision": "block", "reason": "..."}. Fail-open on any error.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Lives in the self-gitignored audit dir so an armed gate can never be
# committed by `git add -A` and pushed to teammates.
GATE="$PROJECT_DIR/.claude/audit/verify-gate"
MAX_ATTEMPTS=3

# Drain stdin (payload unused; presence keeps the contract explicit)
cat >/dev/null 2>&1 || true

[ -f "$GATE" ] || exit 0

# Stale gate (e.g. left by a crashed session): disarm after 2 hours.
# GATE goes in via the environment, never interpolated into python source
# (a quote in the project path must not disable the staleness check).
if command -v python3 >/dev/null 2>&1; then
  STALE=$(GATE="$GATE" python3 -c '
import os, time
try:
    print("yes" if time.time() - os.path.getmtime(os.environ["GATE"]) > 7200 else "no")
except Exception:
    print("yes")
' 2>/dev/null) || STALE="no"
  if [ "$STALE" = "yes" ]; then
    rm -f "$GATE" 2>/dev/null || true
    exit 0
  fi
fi

ATTEMPTS=$(grep -o '[0-9]*' "$GATE" 2>/dev/null | head -1)
[ -z "$ATTEMPTS" ] && ATTEMPTS=0

if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
  # Escape hatch: disarm and let the stop through with a visible warning
  rm -f "$GATE" 2>/dev/null || true
  command -v python3 >/dev/null 2>&1 || exit 0
  python3 -c '
import json
print(json.dumps({"systemMessage": "verify-gate: checks still not green after 3 attempts - gate disarmed. Review the failing gates manually."}))
' 2>/dev/null || true
  exit 0
fi

echo "attempts=$((ATTEMPTS + 1))" > "$GATE" 2>/dev/null || true

command -v python3 >/dev/null 2>&1 || exit 0
N=$((ATTEMPTS + 1)) GATE="$GATE" python3 -c '
import json, os
print(json.dumps({
    "decision": "block",
    "reason": "The /checks verify gate is still armed (%s) - quality gates have not all passed. Re-run the failing gates and fix root causes, then clear the gate with: rm -f \"%s\". If a gate cannot pass for reasons outside this change, say so explicitly with the failing output, then clear the gate. (Attempt %s of 3.)" % (os.environ["GATE"], os.environ["GATE"], os.environ["N"]),
}))
' 2>/dev/null || true

exit 0
