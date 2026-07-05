#!/usr/bin/env bash
set -euo pipefail

# Claude Workflow Installer
# Installs agents, skills, workflows, and hook scripts, and merges settings
# into ~/.claude/. Commands are fully migrated to skills (same /name).
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

if [ -d "$CLAUDE_DIR/skills" ]; then
  cp -r "$CLAUDE_DIR/skills" "$BACKUP_DIR/skills"
  echo "  Backed up skills/"
fi

echo "  Backups saved to: $BACKUP_DIR"
echo ""

# --- Phase 2: Install agents ---
echo "--- Phase 2: Install agents ---"
mkdir -p "$CLAUDE_DIR/agents"
AGENT_COUNT=0
# Core Boris agents
for f in "$SCRIPT_DIR/agents/"*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
  AGENT_COUNT=$((AGENT_COUNT + 1))
done
# Community agents (from agency-agents) — never allowed to shadow a core agent
COLLISIONS=0
for f in "$SCRIPT_DIR/agents/community/"*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  if [ -f "$SCRIPT_DIR/agents/$base" ]; then
    echo "  WARNING: community agent '$base' collides with a core agent -- skipped"
    COLLISIONS=$((COLLISIONS + 1))
    continue
  fi
  cp "$f" "$CLAUDE_DIR/agents/$base"
  AGENT_COUNT=$((AGENT_COUNT + 1))
done
echo "  Installed $AGENT_COUNT agents ($(ls "$SCRIPT_DIR/agents/"*.md 2>/dev/null | wc -l | xargs) core + $(ls "$SCRIPT_DIR/agents/community/"*.md 2>/dev/null | wc -l | xargs) community, $COLLISIONS collision(s) skipped)"

# --- Phase 3: Install workflows ---
echo "--- Phase 3: Install workflows ---"
mkdir -p "$CLAUDE_DIR/workflows"
WF_COUNT=0
for f in "$SCRIPT_DIR/workflows/"*.js; do
  [ -f "$f" ] || continue
  cp "$f" "$CLAUDE_DIR/workflows/$(basename "$f")"
  WF_COUNT=$((WF_COUNT + 1))
done
echo "  Installed $WF_COUNT workflow script(s)"

# --- Phase 3.5: Remove retired files from previous installs ---
echo "--- Phase 3.5: Remove retired files ---"
RETIRED=0
# Commands/agents superseded by native Claude Code features (Boris v3), plus
# retired hook scripts. Flat-copy installs leave stale files behind otherwise —
# and a stale /checkpoint or /mode shadowing the native behavior is worse than none.
for f in \
  commands/checkpoint.md commands/rollback.md commands/undo.md commands/mode.md \
  commands/review-changes.md commands/security-scan.md commands/verify-all.md \
  commands/test-and-fix.md commands/context.md \
  agents/mode-controller.md agents/pr-reviewer.md agents/security-auditor.md \
  agents/verify-app.md agents/code-simplifier.md agents/audit-logger.md \
  agents/boris.md \
  scripts/hook-branch-switch.sh; do
  if [ -f "$CLAUDE_DIR/$f" ]; then
    rm -f "$CLAUDE_DIR/$f"
    RETIRED=$((RETIRED + 1))
  fi
done
echo "  Removed $RETIRED retired file(s) from ~/.claude"

# --- Phase 4: Install skills ---
echo "--- Phase 4: Install skills ---"
mkdir -p "$CLAUDE_DIR/skills"
SKILL_COUNT=0
for d in "$SCRIPT_DIR/skills/"*/; do
  [ -f "$d/SKILL.md" ] || continue
  name=$(basename "$d")
  # Replace, don't merge: a merged copy would keep supporting files that
  # newer repo versions deleted or renamed (stale-file shadowing).
  rm -rf "$CLAUDE_DIR/skills/$name"
  mkdir -p "$CLAUDE_DIR/skills/$name"
  cp -R "$d/." "$CLAUDE_DIR/skills/$name/"
  SKILL_COUNT=$((SKILL_COUNT + 1))
done
echo "  Installed $SKILL_COUNT skills"

# --- Phase 4.5: Remove command flat-copies now superseded by skills ---
# Runs AFTER the skills install so an aborted run can never leave a machine
# with neither the old command nor its skill replacement. Skills win on name
# conflict anyway; this just clears the stale shadow copies.
echo "--- Phase 4.5: Remove superseded command copies ---"
SUPERSEDED=0
for d in "$SCRIPT_DIR/skills/"*/; do
  name=$(basename "$d")
  if [ -f "$CLAUDE_DIR/commands/$name.md" ]; then
    rm -f "$CLAUDE_DIR/commands/$name.md"
    SUPERSEDED=$((SUPERSEDED + 1))
  fi
done
if [ -f "$CLAUDE_DIR/commands/boris.md" ]; then
  rm -f "$CLAUDE_DIR/commands/boris.md"
  SUPERSEDED=$((SUPERSEDED + 1))
fi
if [ -d "$CLAUDE_DIR/skills/boris-workflow" ]; then
  rm -rf "$CLAUDE_DIR/skills/boris-workflow"
  SUPERSEDED=$((SUPERSEDED + 1))
fi
rmdir "$CLAUDE_DIR/commands" 2>/dev/null || true
echo "  Removed $SUPERSEDED superseded command cop(ies)"

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

# --- Phase 5.5: Configure SSH commit signing ---
echo "--- Phase 5.5: Configure SSH commit signing ---"

if [ "${SKIP_SIGNING_SETUP:-0}" = "1" ]; then
  echo "  SKIP_SIGNING_SETUP=1 -- skipping commit signing setup"
else
  CURRENT_SIGN="$(git config --global --get commit.gpgsign 2>/dev/null || true)"
  CURRENT_KEY="$(git config --global --get user.signingkey 2>/dev/null || true)"
  if [ "$CURRENT_SIGN" = "true" ] && [ -n "$CURRENT_KEY" ]; then
    echo "  Already configured (key: $CURRENT_KEY) -- skipping"
  else
    # Find an SSH public key to sign with (prefer id_ed25519)
    SIGNING_KEY=""
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
      SIGNING_KEY="$HOME/.ssh/id_ed25519.pub"
    else
      for k in "$HOME/.ssh/"*.pub; do
        [ -f "$k" ] || continue
        SIGNING_KEY="$k"
        break
      done
    fi

    if [ -z "$SIGNING_KEY" ]; then
      echo "  No SSH public key found in ~/.ssh/ -- NOT enabling signing."
      echo "  Create one:  ssh-keygen -t ed25519 -C \"your_email\""
      echo "  then re-run this installer (or set up signing manually)."
    else
      git config --global gpg.format ssh
      git config --global user.signingkey "$SIGNING_KEY"
      git config --global commit.gpgsign true
      git config --global tag.gpgsign true

      # allowed_signers enables local verification (git log --show-signature)
      SIGNER_EMAIL="$(git config --get user.email 2>/dev/null || true)"
      if [ -n "$SIGNER_EMAIL" ]; then
        mkdir -p "$HOME/.config/git"
        ALLOWED="$HOME/.config/git/allowed_signers"
        ENTRY="$SIGNER_EMAIL $(cat "$SIGNING_KEY")"
        if [ ! -f "$ALLOWED" ] || ! grep -qF "$ENTRY" "$ALLOWED" 2>/dev/null; then
          printf '%s\n' "$ENTRY" >> "$ALLOWED"
        fi
        git config --global gpg.ssh.allowedSignersFile "$ALLOWED"
        echo "  Configured SSH signing (key: $SIGNING_KEY, signer: $SIGNER_EMAIL)"
      else
        echo "  Configured SSH signing (key: $SIGNING_KEY)"
        echo "  Set user.email and re-run to enable local verification."
      fi

      echo ""
      echo "  ACTION REQUIRED -- register this key as a SIGNING key on GitHub:"
      echo "    $(cat "$SIGNING_KEY")"
      echo "  CLI:  gh auth refresh -h github.com -s admin:ssh_signing_key && gh ssh-key add \"$SIGNING_KEY\" --type signing"
      echo "  Web:  https://github.com/settings/ssh/new  (Key type: Signing Key)"
    fi
  fi
fi
echo ""

# --- Phase 6: Install hook scripts ---
echo "--- Phase 6: Install hook scripts ---"
mkdir -p "$CLAUDE_DIR/scripts"
SCRIPT_COUNT=0
for f in "$SCRIPT_DIR/scripts/"*.sh; do
  [ -f "$f" ] || continue
  cp "$f" "$CLAUDE_DIR/scripts/$(basename "$f")"
  chmod +x "$CLAUDE_DIR/scripts/$(basename "$f")"
  SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
done
echo "  Installed $SCRIPT_COUNT hook scripts"

# --- Phase 6.3: Install rules ---
echo "--- Phase 6.3: Install rules ---"
mkdir -p "$CLAUDE_DIR/rules"
RULES_COUNT=0
for f in "$SCRIPT_DIR/rules/"*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  if [ "$base" = "learned-patterns.md" ]; then
    # The lessons file is the sync target and accumulates the machine's own
    # (private) lessons — seed it only when absent, never overwrite.
    if [ ! -f "$CLAUDE_DIR/rules/$base" ]; then
      cp "$f" "$CLAUDE_DIR/rules/$base"
      RULES_COUNT=$((RULES_COUNT + 1))
      echo "  Seeded rules/learned-patterns.md from repo"
    fi
  else
    cp "$f" "$CLAUDE_DIR/rules/$base"
    RULES_COUNT=$((RULES_COUNT + 1))
  fi
done
echo "  Installed $RULES_COUNT rules file(s) to ~/.claude/rules/"

# --- Phase 6.5: Install context templates ---
echo "--- Phase 6.5: Install context templates ---"
mkdir -p "$CLAUDE_DIR/context/patterns"
CONTEXT_COUNT=0
if [ -f "$SCRIPT_DIR/context/ROUTER.md" ]; then
  cp "$SCRIPT_DIR/context/ROUTER.md" "$CLAUDE_DIR/context/ROUTER.md"
  CONTEXT_COUNT=$((CONTEXT_COUNT + 1))
fi
if [ -f "$SCRIPT_DIR/context/patterns/INDEX.md" ]; then
  cp "$SCRIPT_DIR/context/patterns/INDEX.md" "$CLAUDE_DIR/context/patterns/INDEX.md"
  CONTEXT_COUNT=$((CONTEXT_COUNT + 1))
fi
echo "  Installed $CONTEXT_COUNT context templates (ROUTER.md, patterns/INDEX.md)"

# --- Phase 7: Install CLAUDE.md + migrate lessons to the rules file ---
echo "--- Phase 7: CLAUDE.md + lesson migration ---"

# Boris v3: lessons live in ~/.claude/rules/learned-patterns.md, not CLAUDE.md.
# The version stamp is an HTML comment ("boris-version: 3") because users edit
# prose headings; the stamp is the one line they're told not to remove.
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && ! grep -q "boris-version: 3" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
  # Pre-v3 (or pre-Boris) CLAUDE.md: migrate its Learned Patterns into the
  # local rules file BEFORE replacing the structure. The merge is the ungated
  # Repo->Local direction (REPO_FILE = the old file snapshot, never the public
  # repo), so private/untagged lessons are preserved locally and never leak.
  SNAPSHOT="$(mktemp)"
  cp "$CLAUDE_DIR/CLAUDE.md" "$SNAPSHOT"
  MIGRATION_OK=true
  if grep -q '^# Learned Patterns' "$SNAPSHOT" 2>/dev/null; then
    [ -f "$CLAUDE_DIR/rules/learned-patterns.md" ] || printf '# Learned Patterns\n' > "$CLAUDE_DIR/rules/learned-patterns.md"
    if LOCAL_FILE="$CLAUDE_DIR/rules/learned-patterns.md" REPO_FILE="$SNAPSHOT" \
       "$SCRIPT_DIR/sync-lessons.sh" >/dev/null 2>&1; then
      echo "  Migrated Learned Patterns from old CLAUDE.md into rules/learned-patterns.md"
    else
      MIGRATION_OK=false
    fi
  fi

  if [ "$MIGRATION_OK" = "true" ]; then
    # Preserve user-authored content: carry over any top-level section whose
    # heading is not part of the known template, appending it to the new file.
    CUSTOM="$(mktemp)"
    awk '
      /^# / {
        keep = 1
        if ($0 ~ /^# (Session Boot|User Preferences|Quick Reference|Workflow Orchestration|Memory Bank|Core Principles|Learned Patterns|Rules)/) keep = 0
      }
      keep { print }
    ' "$SNAPSHOT" > "$CUSTOM"
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    if [ -s "$CUSTOM" ]; then
      { echo ""; cat "$CUSTOM"; } >> "$CLAUDE_DIR/CLAUDE.md"
      echo "  Carried over custom section(s) from your old CLAUDE.md:"
      grep '^# ' "$CUSTOM" | sed 's/^/    /'
    fi
    rm -f "$CUSTOM"
    # @imports inside template-owned sections do not survive the replacement
    if grep -qE '^\s*@[~./]' "$SNAPSHOT" && ! grep -qE '^\s*@[~./]' "$CLAUDE_DIR/CLAUDE.md"; then
      echo "  WARNING: your old CLAUDE.md contained @import lines that were not carried over."
      echo "  Re-add them from the backup if still needed: $BACKUP_DIR/CLAUDE.md"
    fi
    echo "  Installed slim Boris v3 CLAUDE.md (old version in backup: $BACKUP_DIR)"
  else
    echo "  ERROR: lesson migration FAILED — your existing CLAUDE.md was left unchanged."
    echo "  No lessons were lost. Fix the issue (run ./sync-lessons.sh manually to see the"
    echo "  error with LOCAL_FILE=$CLAUDE_DIR/rules/learned-patterns.md) and re-run install.sh."
  fi
  rm -f "$SNAPSHOT"
elif [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  Installed CLAUDE.md (fresh install)"
else
  echo "  CLAUDE.md already at Boris v3"
fi

# Sync lessons between the repo and the machine rules file. Local -> repo
# promotion stays OPT-IN via the <!-- shareable --> marker.
"$SCRIPT_DIR/sync-lessons.sh" || echo "  WARNING: lesson sync failed — run ./sync-lessons.sh manually to see the error"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed:"
echo "  - $AGENT_COUNT agents"
echo "  - $SKILL_COUNT skills (invoked as /name — commands are fully migrated to skills)"
echo "  - $WF_COUNT workflow script(s)"
echo "  - $SCRIPT_COUNT hook scripts"
echo "  - rules/ (git-safety, workflow, learned-patterns — the lesson-capture target)"
echo "  - $CONTEXT_COUNT context templates"
echo "  - settings.json (merged with hooks)"
echo "  - CLAUDE.md (slim v3 core; lessons live in rules/learned-patterns.md)"
echo ""
echo "Backup at: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Open a new Claude Code session"
echo "  2. Type / to see all available commands"
echo "  3. Run /memory-init in any project to set up Memory Bank"
echo "  4. Run /session-start to begin a session"
echo ""
echo "To sync lessons across machines (only <!-- shareable --> lessons reach the public repo):"
echo "  ./sync-lessons.sh && git add rules/learned-patterns.md && git commit -m 'sync lessons' && git push"
