#!/usr/bin/env bash
set -euo pipefail

# Claude Workflow Uninstaller
# Restores from the most recent backup

CLAUDE_DIR="$HOME/.claude"
BACKUP_BASE="$CLAUDE_DIR/backups"

echo "=== Claude Workflow Uninstaller ==="

# Find most recent backup (|| true: under set -e/pipefail a missing backup
# dir would otherwise kill the script before the friendly message below)
LATEST_BACKUP=$(ls -dt "$BACKUP_BASE"/workflow-* 2>/dev/null | head -1 || true)

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

# Skills: restore the backup snapshot when one exists (symmetric with agents/ —
# a user's pre-existing same-named skill comes back); otherwise remove exactly
# what this repo installed (derived from the repo's own skills/ dir so the
# list never goes stale; boris-workflow covers old installs)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$LATEST_BACKUP/skills" ]; then
  rm -rf "$CLAUDE_DIR/skills"
  cp -r "$LATEST_BACKUP/skills" "$CLAUDE_DIR/skills"
  echo "  Restored skills/ from backup"
else
  for d in "$SCRIPT_DIR/skills/"*/; do
    name=$(basename "$d")
    if [ -d "$CLAUDE_DIR/skills/$name" ]; then
      rm -rf "$CLAUDE_DIR/skills/$name"
      echo "  Removed skill: $name"
    fi
  done
fi
if [ -d "$CLAUDE_DIR/skills/boris-workflow" ]; then
  rm -rf "$CLAUDE_DIR/skills/boris-workflow"
  echo "  Removed boris-workflow skill"
fi
for f in "$SCRIPT_DIR/workflows/"*.js; do
  [ -f "$f" ] || continue
  if [ -f "$CLAUDE_DIR/workflows/$(basename "$f")" ]; then
    rm -f "$CLAUDE_DIR/workflows/$(basename "$f")"
    echo "  Removed workflow: $(basename "$f")"
  fi
done

# Rules: remove the repo-shipped rule files, but KEEP learned-patterns.md —
# it accumulates the machine's own private lessons and is not replaceable.
for r in git-safety.md workflow.md; do
  if [ -f "$CLAUDE_DIR/rules/$r" ]; then
    rm -f "$CLAUDE_DIR/rules/$r"
    echo "  Removed rules/$r"
  fi
done
if [ -f "$CLAUDE_DIR/rules/learned-patterns.md" ]; then
  echo "  Kept rules/learned-patterns.md (your accumulated lessons — delete manually if desired)"
fi

# Remove workflow-installed hook scripts and context templates.
# hook-*.sh is globbed so future hooks (and long-retired ones from old
# installs) are covered without maintaining an enumerated list.
for s in "$CLAUDE_DIR/scripts/"hook-*.sh \
         "$CLAUDE_DIR/scripts/drift-check.sh" \
         "$CLAUDE_DIR/scripts/sync-agency-agents.sh" \
         "$CLAUDE_DIR/scripts/test-hooks.sh"; do
  if [ -f "$s" ]; then
    rm -f "$s"
    echo "  Removed scripts/$(basename "$s")"
  fi
done
rm -f "$CLAUDE_DIR/context/ROUTER.md" "$CLAUDE_DIR/context/patterns/INDEX.md" 2>/dev/null || true

# On a machine where install.sh was the FIRST thing to create settings.json,
# there was no backup to restore — the workflow settings (and their hook
# wiring, now pointing at deleted scripts) are still in place.
if [ ! -f "$LATEST_BACKUP/settings.json" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
  echo ""
  echo "  WARNING: no settings.json backup existed (fresh-install machine)."
  echo "  ~/.claude/settings.json still contains the workflow's hook wiring and"
  echo "  permissions. Remove the 'hooks' block manually (the scripts it points"
  echo "  to are gone) or delete the file if you had no prior settings."
fi

echo ""
echo "=== Uninstall Complete ==="
echo "Restored to state from: $(basename "$LATEST_BACKUP")"
echo ""
echo "Start a new Claude Code session for changes to take effect."
