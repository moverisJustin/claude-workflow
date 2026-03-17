#!/usr/bin/env bash
# Hook: PreToolUse (Bash)
# Auto-checkpoint before destructive git/file operations
# Context impact: ZERO — PreToolUse output stays outside context window

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
CONFIG_FILE="$PROJECT_DIR/.claude/project-config.json"
AUDIT_DIR="$PROJECT_DIR/.claude/audit"

# If no tool input, nothing to check
[ -z "$TOOL_INPUT" ] && exit 0

# Check project config — skip git guards if git is disabled
if [ -f "$CONFIG_FILE" ]; then
  GIT_ENABLED=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('git_enabled', True))" 2>/dev/null || echo "True")
  if [ "$GIT_ENABLED" = "False" ] || [ "$GIT_ENABLED" = "false" ]; then
    exit 0
  fi
fi

# Destructive patterns to guard against
# Match at word boundaries to avoid false positives (e.g., grep "git reset" in docs)
DESTRUCTIVE=false
PATTERN=""

case "$TOOL_INPUT" in
  git\ reset\ --hard*)     DESTRUCTIVE=true; PATTERN="git reset --hard" ;;
  git\ clean\ -f*)         DESTRUCTIVE=true; PATTERN="git clean -f" ;;
  git\ checkout\ .)        DESTRUCTIVE=true; PATTERN="git checkout ." ;;
  git\ checkout\ --\ .)    DESTRUCTIVE=true; PATTERN="git checkout -- ." ;;
  git\ restore\ .)         DESTRUCTIVE=true; PATTERN="git restore ." ;;
  git\ restore\ --staged\ .) DESTRUCTIVE=true; PATTERN="git restore --staged ." ;;
  git\ push\ --force*)     DESTRUCTIVE=true; PATTERN="git push --force" ;;
  git\ push\ -f*)          DESTRUCTIVE=true; PATTERN="git push -f" ;;
  rm\ -rf\ *)              DESTRUCTIVE=true; PATTERN="rm -rf" ;;
  rm\ -r\ -f\ *)           DESTRUCTIVE=true; PATTERN="rm -rf" ;;
esac

# If not destructive, allow silently
[ "$DESTRUCTIVE" = "false" ] && exit 0

# Check if we're in a git repo
if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  # Not a git repo — can't checkpoint, but don't block non-git ops like rm -rf
  if [[ "$PATTERN" == rm* ]]; then
    # Log but allow rm -rf in non-git dirs
    mkdir -p "$AUDIT_DIR" 2>/dev/null || true
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) WARN no-git-checkpoint $PATTERN: $TOOL_INPUT" >> "$AUDIT_DIR/destructive-guard.log" 2>/dev/null || true
    exit 0
  fi
  exit 0
fi

# Create checkpoint
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CHECKPOINT_TAG="auto-checkpoint/$TIMESTAMP"

# Tag current HEAD
if ! git -C "$PROJECT_DIR" tag "$CHECKPOINT_TAG" 2>/dev/null; then
  echo "Failed to create safety checkpoint tag. Blocking destructive operation." >&2
  exit 2
fi

# Stash dirty working tree if needed
if ! git -C "$PROJECT_DIR" diff --quiet 2>/dev/null || ! git -C "$PROJECT_DIR" diff --cached --quiet 2>/dev/null; then
  git -C "$PROJECT_DIR" stash push -m "auto-checkpoint-$TIMESTAMP" 2>/dev/null || true
fi

# Log the checkpoint
mkdir -p "$AUDIT_DIR" 2>/dev/null || true
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) CHECKPOINT $CHECKPOINT_TAG before: $TOOL_INPUT" >> "$AUDIT_DIR/destructive-guard.log" 2>/dev/null || true

# Allow the operation to proceed
exit 0
