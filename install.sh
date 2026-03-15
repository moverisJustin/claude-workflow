#!/usr/bin/env bash
set -euo pipefail

# Claude Workflow Installer
# Installs agents, commands, skills, and merges settings into ~/.claude/
# Safe to run multiple times (idempotent)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/workflow-$(date +%Y%m%d-%H%M%S)"

echo "=== Claude Workflow Installer ==="
echo "Source: $SCRIPT_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# --- Phase 1: Backup ---
echo "--- Phase 1: Backup ---"
mkdir -p "$BACKUP_DIR"

if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/CLAUDE.md"
  echo "  Backed up CLAUDE.md"
fi

if [ -f "$CLAUDE_DIR/settings.json" ]; then
  cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/settings.json"
  echo "  Backed up settings.json"
fi

if [ -d "$CLAUDE_DIR/agents" ]; then
  cp -r "$CLAUDE_DIR/agents" "$BACKUP_DIR/agents"
  echo "  Backed up agents/"
fi

if [ -d "$CLAUDE_DIR/commands" ]; then
  cp -r "$CLAUDE_DIR/commands" "$BACKUP_DIR/commands"
  echo "  Backed up commands/"
fi

echo "  Backups saved to: $BACKUP_DIR"
echo ""

# --- Phase 2: Install agents ---
echo "--- Phase 2: Install agents ---"
mkdir -p "$CLAUDE_DIR/agents"
AGENT_COUNT=0
for f in "$SCRIPT_DIR/agents/"*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
  AGENT_COUNT=$((AGENT_COUNT + 1))
done
echo "  Installed $AGENT_COUNT agents"

# --- Phase 3: Install commands ---
echo "--- Phase 3: Install commands ---"
mkdir -p "$CLAUDE_DIR/commands"
CMD_COUNT=0
for f in "$SCRIPT_DIR/commands/"*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$CLAUDE_DIR/commands/$(basename "$f")"
  CMD_COUNT=$((CMD_COUNT + 1))
done
echo "  Installed $CMD_COUNT commands"

# --- Phase 4: Install skills ---
echo "--- Phase 4: Install skills ---"
mkdir -p "$CLAUDE_DIR/skills/boris-workflow"
if [ -f "$SCRIPT_DIR/skills/boris-workflow/SKILL.md" ]; then
  cp "$SCRIPT_DIR/skills/boris-workflow/SKILL.md" "$CLAUDE_DIR/skills/boris-workflow/SKILL.md"
  echo "  Installed boris-workflow skill"
fi

# --- Phase 5: Merge settings.json ---
echo "--- Phase 5: Merge settings.json ---"

if ! command -v jq &>/dev/null; then
  echo "  WARNING: jq not found. Skipping settings merge."
  echo "  Install jq and re-run, or manually merge settings.base.json into ~/.claude/settings.json"
else
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    # Merge: base settings + existing machine-specific entries
    # Strategy:
    #   - allow: union (base wildcards + existing machine-specific entries not covered by wildcards)
    #   - deny: take from base (authoritative)
    #   - hooks: take from base (authoritative)
    #   - env: take from base (authoritative)
    #   - additionalDirectories: keep existing
    #   - enabledPlugins: keep existing

    EXISTING="$CLAUDE_DIR/settings.json"
    BASE="$SCRIPT_DIR/settings.base.json"
    MERGED=$(mktemp)

    jq -s '
      # $existing = .[0], $base = .[1]
      .[0] as $existing | .[1] as $base |

      # Get existing allow entries not in base (machine-specific)
      ($base.permissions.allow | map(ascii_downcase)) as $base_lower |
      ($existing.permissions.allow // [] | map(select(ascii_downcase as $e | $base_lower | map(. == $e) | any | not))) as $machine_specific |

      {
        permissions: {
          allow: ($base.permissions.allow + $machine_specific | unique),
          deny: $base.permissions.deny,
          additionalDirectories: ($existing.permissions.additionalDirectories // [])
        },
        hooks: $base.hooks,
        env: $base.env,
        enabledPlugins: ($existing.enabledPlugins // {})
      }
    ' "$EXISTING" "$BASE" > "$MERGED"

    # Validate merged JSON
    if jq empty "$MERGED" 2>/dev/null; then
      cp "$MERGED" "$CLAUDE_DIR/settings.json"
      echo "  Merged settings.json (preserved machine-specific entries)"
    else
      echo "  ERROR: Merged settings.json is invalid. Kept existing."
    fi
    rm -f "$MERGED"
  else
    # No existing settings, just copy base
    cp "$SCRIPT_DIR/settings.base.json" "$CLAUDE_DIR/settings.json"
    echo "  Installed settings.json (fresh install)"
  fi
fi

# --- Phase 6: Merge CLAUDE.md (with lesson sync) ---
echo "--- Phase 6: Merge CLAUDE.md ---"

if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  # Sync lessons between repo and local
  "$SCRIPT_DIR/sync-lessons.sh" || echo "  Lesson sync skipped (sync-lessons.sh not found or failed)"

  # Copy everything EXCEPT the Learned Patterns section from repo
  # (lessons are handled by sync-lessons.sh)
  # For now, only sync lessons. The rest of CLAUDE.md structure is managed by install.

  # Check if local CLAUDE.md has the Boris sections
  if ! grep -q "Quick Reference (Boris v2.0)" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
    # Local CLAUDE.md doesn't have Boris sections yet -- replace with repo version
    # but preserve any local Learned Patterns first
    "$SCRIPT_DIR/sync-lessons.sh" 2>/dev/null || true
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    "$SCRIPT_DIR/sync-lessons.sh" 2>/dev/null || true
    echo "  Installed CLAUDE.md with Boris workflow (lessons preserved)"
  else
    echo "  CLAUDE.md already has Boris sections (lessons synced)"
  fi
else
  cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  Installed CLAUDE.md (fresh install)"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed:"
echo "  - $AGENT_COUNT agents"
echo "  - $CMD_COUNT commands"
echo "  - 1 skill (boris-workflow)"
echo "  - settings.json (merged)"
echo "  - CLAUDE.md (with lessons synced)"
echo ""
echo "Backup at: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Open a new Claude Code session"
echo "  2. Type / to see all available commands"
echo "  3. Run /memory-init in any project to set up Memory Bank"
echo "  4. Run /session-start to begin a session"
echo ""
echo "To sync lessons across machines:"
echo "  ./sync-lessons.sh && git add CLAUDE.md && git commit -m 'sync lessons' && git push"
