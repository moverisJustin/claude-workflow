#!/usr/bin/env bash
# Hook: PostToolUse (Bash)
# Log branch switches and auto-stash uncommitted changes
# Context impact: ZERO — PostToolUse output stays outside context window

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
CONFIG_FILE="$PROJECT_DIR/.claude/project-config.json"
AUDIT_DIR="$PROJECT_DIR/.claude/audit"

# If no tool input, nothing to check
[ -z "$TOOL_INPUT" ] && exit 0

# Check project config — skip if git is disabled
if [ -f "$CONFIG_FILE" ]; then
  GIT_ENABLED=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('git_enabled', True))" 2>/dev/null || echo "True")
  if [ "$GIT_ENABLED" = "False" ] || [ "$GIT_ENABLED" = "false" ]; then
    exit 0
  fi
fi

# Detect branch switch operations (avoid false positives with file checkouts)
IS_BRANCH_SWITCH=false

case "$TOOL_INPUT" in
  git\ switch\ *)          IS_BRANCH_SWITCH=true ;;
  git\ checkout\ -b\ *)    IS_BRANCH_SWITCH=true ;;
  git\ checkout\ -B\ *)    IS_BRANCH_SWITCH=true ;;
esac

# For bare "git checkout <name>", only match if it looks like a branch name
# (no dots, no slashes except feature/fix/task prefixes, no file extensions)
if [ "$IS_BRANCH_SWITCH" = "false" ]; then
  if echo "$TOOL_INPUT" | grep -qE '^git checkout (feature/|fix/|task/|bugfix/|hotfix/|release/|main$|master$|develop$|dev$|staging$|production$)'; then
    IS_BRANCH_SWITCH=true
  fi
fi

# If not a branch switch, exit silently
[ "$IS_BRANCH_SWITCH" = "false" ] && exit 0

# Check if we're in a git repo
if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Get current branch before switch (PostToolUse fires after, but branch name may already be changed)
CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")

# Log the branch switch
mkdir -p "$AUDIT_DIR" 2>/dev/null || true
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BRANCH_SWITCH to=$CURRENT_BRANCH cmd=$TOOL_INPUT" >> "$AUDIT_DIR/branch-switches.log" 2>/dev/null || true

# Note: Auto-stash before switch would need PreToolUse, not PostToolUse.
# PostToolUse fires AFTER the switch already happened.
# If the switch failed due to dirty tree, git would have blocked it already.
# This hook is primarily for audit logging.

exit 0
