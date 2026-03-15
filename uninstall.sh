#!/usr/bin/env bash
set -euo pipefail

# Claude Workflow Uninstaller
# Restores from the most recent backup

CLAUDE_DIR="$HOME/.claude"
BACKUP_BASE="$CLAUDE_DIR/backups"

echo "=== Claude Workflow Uninstaller ==="

# Find most recent backup
LATEST_BACKUP=$(ls -dt "$BACKUP_BASE"/workflow-* 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
  echo "No backups found in $BACKUP_BASE/workflow-*"
  echo "Cannot uninstall without a backup."
  exit 1
fi

echo "Restoring from: $LATEST_BACKUP"
echo ""

# Restore CLAUDE.md
if [ -f "$LATEST_BACKUP/CLAUDE.md" ]; then
  cp "$LATEST_BACKUP/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  Restored CLAUDE.md"
fi

# Restore settings.json
if [ -f "$LATEST_BACKUP/settings.json" ]; then
  cp "$LATEST_BACKUP/settings.json" "$CLAUDE_DIR/settings.json"
  echo "  Restored settings.json"
fi

# Restore agents (replace directory)
if [ -d "$LATEST_BACKUP/agents" ]; then
  rm -rf "$CLAUDE_DIR/agents"
  cp -r "$LATEST_BACKUP/agents" "$CLAUDE_DIR/agents"
  echo "  Restored agents/"
elif [ -d "$CLAUDE_DIR/agents" ]; then
  rm -rf "$CLAUDE_DIR/agents"
  echo "  Removed agents/ (no backup existed)"
fi

# Restore commands (replace directory)
if [ -d "$LATEST_BACKUP/commands" ]; then
  rm -rf "$CLAUDE_DIR/commands"
  cp -r "$LATEST_BACKUP/commands" "$CLAUDE_DIR/commands"
  echo "  Restored commands/"
fi

# Remove skills added by workflow
if [ -d "$CLAUDE_DIR/skills/boris-workflow" ]; then
  rm -rf "$CLAUDE_DIR/skills/boris-workflow"
  echo "  Removed boris-workflow skill"
fi

echo ""
echo "=== Uninstall Complete ==="
echo "Restored to state from: $(basename "$LATEST_BACKUP")"
echo ""
echo "Start a new Claude Code session for changes to take effect."
