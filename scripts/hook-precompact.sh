#!/usr/bin/env bash
# Hook: PreCompact (manual + auto)
# Fires right before context compaction — the exact moment the working
# mental model is at risk.
#
# Contract note: PreCompact supports NO context injection (only a top-level
# {"decision":"block"}), so this hook is a pure SIDE EFFECT: it writes a
# mechanical git-state snapshot to .claude/memory/compaction-snapshot.md.
# The companion hook-compact-resume.sh (SessionStart, matcher "compact")
# injects the recovery directive AFTER compaction, where stdout does reach
# context. Together they replace the old CLAUDE.md "Context Guardian"
# 60%/75% protocol, which could never fire (the model cannot observe its
# own context usage).

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEMORY_DIR="$PROJECT_DIR/.claude/memory"

# Only snapshot in Memory Bank projects — elsewhere there is nowhere
# agreed-upon to write, and silence is the fail-open behavior.
[ -d "$MEMORY_DIR" ] || exit 0

SNAPSHOT="$MEMORY_DIR/compaction-snapshot.md"
{
  echo "# Compaction Snapshot"
  echo ""
  echo "Mechanical git state captured immediately before context compaction."
  echo "Written by hook-precompact.sh; read via hook-compact-resume.sh."
  echo ""
  echo "- **When**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "- **Branch**: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo detached)"
    echo "- **Uncommitted**:"
    git -C "$PROJECT_DIR" status --short 2>/dev/null | head -15 | sed 's/^/  - `/;s/$/`/'
    echo "- **Recent commits**:"
    git -C "$PROJECT_DIR" log --oneline -5 2>/dev/null | sed 's/^/  - /'
  else
    echo "- **Git**: not a repository"
  fi
  if [ -f "$PROJECT_DIR/.claude/task-context.md" ]; then
    echo "- **Task context**: .claude/task-context.md exists on this branch — verify it is current."
  fi
} > "$SNAPSHOT" 2>/dev/null || true

exit 0
