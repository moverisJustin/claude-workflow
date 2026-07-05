#!/usr/bin/env bash
# Hook: SessionStart (matcher: "compact")
# Fires immediately AFTER context compaction. SessionStart stdout is
# injected into context, so this is the supported channel for the
# post-compaction recovery directive (PreCompact itself consumes no
# hook output — see hook-precompact.sh, which writes the snapshot).
# HARD CAP: keep output small; this lands in every post-compaction context.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SNAPSHOT="$PROJECT_DIR/.claude/memory/compaction-snapshot.md"

echo "[Post-compaction recovery]"
echo "Context was just compacted. If mid-task: (1) verify the summary against real state before acting;"
if [ -f "$SNAPSHOT" ]; then
  echo "(2) compare with the pre-compaction git snapshot in .claude/memory/compaction-snapshot.md;"
fi
if [ -f "$PROJECT_DIR/.claude/task-context.md" ]; then
  echo "(3) update .claude/task-context.md with a cognitive handoff (resume prompt, mental model, failed approaches, next steps) before continuing — see /handoff."
else
  echo "(3) if work is non-trivial, save a cognitive handoff now (resume prompt, failed approaches, next steps) — see /handoff."
fi

exit 0
