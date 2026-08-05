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

# --- Phase 0: Self-update the clone before installing ---
# install.sh installs whatever version THIS clone is at. A clone that hasn't
# been pulled installs an OLD version — the #1 "I installed v2.0 by accident"
# trap. So bring the clone to latest first, then re-exec the updated installer.
# Opt out with BORIS_INSTALL_NO_SELF_UPDATE=1. The re-exec guard prevents loops.
if [ -z "${BORIS_INSTALL_NO_SELF_UPDATE:-}" ] && [ -z "${BORIS_INSTALL_REEXEC:-}" ] \
   && git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1 \
   && git -C "$SCRIPT_DIR" remote get-url origin >/dev/null 2>&1; then
  git -C "$SCRIPT_DIR" fetch -q origin 2>/dev/null || true
  REMOTE_REF=""
  for ref in origin/main origin/master; do
    if git -C "$SCRIPT_DIR" rev-parse --verify -q "$ref" >/dev/null 2>&1; then REMOTE_REF="$ref"; break; fi
  done
  if [ -n "$REMOTE_REF" ]; then
    BEHIND=$(git -C "$SCRIPT_DIR" rev-list --count "HEAD..$REMOTE_REF" 2>/dev/null || echo 0)
    if [ "${BEHIND:-0}" -gt 0 ]; then
      DIRTY=$(git -C "$SCRIPT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      if [ "$DIRTY" = "0" ] && git -C "$SCRIPT_DIR" merge-base --is-ancestor HEAD "$REMOTE_REF" 2>/dev/null; then
        echo "--- Phase 0: Update clone ---"
        echo "  This clone was $BEHIND commit(s) behind $REMOTE_REF — updating to latest first."
        git -C "$SCRIPT_DIR" merge --ff-only "$REMOTE_REF" >/dev/null 2>&1 || true
        echo "  Re-running the updated installer."
        echo ""
        BORIS_INSTALL_REEXEC=1 exec bash "$SCRIPT_DIR/install.sh" "$@"
      else
        echo "  WARNING: this clone is $BEHIND commit(s) behind $REMOTE_REF and can't fast-forward"
        echo "  (uncommitted changes or diverged history) — you may be installing an OLD version."
        echo "  Fix: git -C \"$SCRIPT_DIR\" pull --ff-only   then re-run ./install.sh"
        echo ""
      fi
    fi
  fi
fi

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
# Community agents (from agency-agents) — install ONLY the agents listed as
# active (uncommented) in MANIFEST.txt, not every vendored file. Each installed
# copy gets a model tier + (for advisory personas) a read-only tool set applied
# at deploy time. Never allowed to shadow a core agent.
. "$SCRIPT_DIR/scripts/agent-tier.sh"
CORE_COUNT=$(ls "$SCRIPT_DIR/agents/"*.md 2>/dev/null | wc -l | xargs)
COLLISIONS=0
COMMUNITY_COUNT=0
MANIFEST="$SCRIPT_DIR/agents/community/MANIFEST.txt"
if [ -f "$MANIFEST" ]; then
  while IFS= read -r slug; do
    slug=$(printf '%s' "$slug" | sed 's/#.*//' | xargs)
    [ -z "$slug" ] && continue
    src="$SCRIPT_DIR/agents/community/$slug.md"
    [ -f "$src" ] || continue
    if [ -f "$SCRIPT_DIR/agents/$slug.md" ]; then
      echo "  WARNING: community agent '$slug' collides with a core agent -- skipped"
      COLLISIONS=$((COLLISIONS + 1))
      continue
    fi
    cp "$src" "$CLAUDE_DIR/agents/$slug.md"
    inject_agent_frontmatter "$CLAUDE_DIR/agents/$slug.md" "$slug"
    COMMUNITY_COUNT=$((COMMUNITY_COUNT + 1))
    AGENT_COUNT=$((AGENT_COUNT + 1))
  done < "$MANIFEST"

  # Prune now-inactive community agents left by an older install that deployed
  # more (or all) of them. Only ever removes agents this repo vendors under
  # agents/community/ AND that are not currently active — never the user's own
  # custom agents or the core set.
  PRUNED=0
  # `if` (not `&& echo`): the last MANIFEST line is a comment, so the final
  # iteration must exit 0, or the command substitution's non-zero status trips
  # `set -e` and aborts the install.
  ACTIVE_LIST="$(sed 's/#.*//' "$MANIFEST" | while IFS= read -r l; do s=$(printf '%s' "$l" | xargs); if [ -n "$s" ]; then echo "$s"; fi; done)"
  for vf in "$SCRIPT_DIR/agents/community/"*.md; do
    [ -f "$vf" ] || continue
    vslug=$(basename "$vf" .md)
    printf '%s\n' "$ACTIVE_LIST" | grep -qxF "$vslug" && continue   # still active
    if [ -f "$CLAUDE_DIR/agents/$vslug.md" ]; then
      rm -f "$CLAUDE_DIR/agents/$vslug.md"
      PRUNED=$((PRUNED + 1))
    fi
  done
fi
echo "  Installed $AGENT_COUNT agents ($CORE_COUNT core + $COMMUNITY_COUNT community active, $COLLISIONS collision(s) skipped, ${PRUNED:-0} now-inactive pruned)"
echo "  ($(ls "$SCRIPT_DIR/agents/community/"*.md 2>/dev/null | wc -l | xargs) community agents vendored; enable more by uncommenting them in agents/community/MANIFEST.txt and re-running)"

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
# Commands/agents retired WITHOUT a same-named skill/agent successor. (Migrated
# commands are cleaned by Phase 4.5 because a skill of the same name exists;
# these have no successor, so they must be listed explicitly or they linger.)
# When you retire something with no replacement, ADD IT HERE — this list fell
# behind twice (load-context retired in P3, ci-integrator in 4b) and left
# stale files on upgraded machines.
for f in \
  commands/checkpoint.md commands/rollback.md commands/undo.md commands/mode.md \
  commands/review-changes.md commands/security-scan.md commands/verify-all.md \
  commands/test-and-fix.md commands/context.md commands/load-context.md \
  agents/mode-controller.md agents/pr-reviewer.md agents/security-auditor.md \
  agents/verify-app.md agents/code-simplifier.md agents/audit-logger.md \
  agents/boris.md agents/ci-integrator.md \
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
for f in "$SCRIPT_DIR/scripts/"*.sh "$SCRIPT_DIR/scripts/"*.mjs; do
  [ -f "$f" ] || continue
  cp "$f" "$CLAUDE_DIR/scripts/$(basename "$f")"
  chmod +x "$CLAUDE_DIR/scripts/$(basename "$f")"
  SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
done
echo "  Installed $SCRIPT_COUNT hook scripts"

# --- Phase 6.3: Install rules ---
echo "--- Phase 6.3: Install rules ---"
mkdir -p "$CLAUDE_DIR/rules" "$CLAUDE_DIR/lessons"

# v3.1 MIGRATION — must run BEFORE the rules/ copy loop below.
#
# Through v3.0 the whole lesson corpus lived at rules/learned-patterns.md, which the
# harness auto-loads: ~100KB into every session in every project. v3.1 keeps a curated
# hot core there and moves the corpus to lessons/, retrieved on demand.
#
# The copy loop below now overwrites rules/learned-patterns.md unconditionally, so a
# pre-3.1 machine would lose its private lessons unless they are moved out FIRST.
# Detect by CONTENT, not by version stamp: the v3.1 file carries the index marker and
# a pre-3.1 corpus never does.
V31_MARKER='## Deferred corpus — heading index'
OLD_LP="$CLAUDE_DIR/rules/learned-patterns.md"
if [ -f "$OLD_LP" ] && ! grep -qF "$V31_MARKER" "$OLD_LP"; then
  if [ -f "$CLAUDE_DIR/lessons/learned-patterns.md" ]; then
    # Both exist and rules/ is still a pre-3.1 corpus: merge rather than clobber.
    if LOCAL_FILE="$CLAUDE_DIR/lessons/learned-patterns.md" REPO_FILE="$OLD_LP" \
       "$SCRIPT_DIR/sync-lessons.sh" >/dev/null 2>&1; then
      echo "  Merged pre-3.1 rules/learned-patterns.md into lessons/ (no lessons lost)"
    else
      echo "  ERROR: could not merge pre-3.1 lessons. Aborting before overwrite." >&2
      echo "  Your lessons are untouched at $OLD_LP — re-run after resolving." >&2
      exit 1
    fi
  else
    mv "$OLD_LP" "$CLAUDE_DIR/lessons/learned-patterns.md"
    echo "  Moved pre-3.1 lesson corpus to lessons/learned-patterns.md ($(wc -c < "$CLAUDE_DIR/lessons/learned-patterns.md" | tr -d ' ') bytes out of always-on context)"
  fi
fi

RULES_COUNT=0
for f in "$SCRIPT_DIR/rules/"*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  cp "$f" "$CLAUDE_DIR/rules/$base"
  RULES_COUNT=$((RULES_COUNT + 1))
done
echo "  Installed $RULES_COUNT rules file(s) to ~/.claude/rules/"

# Seed the corpus on a fresh machine only — it accumulates private lessons, so it is
# never overwritten once it exists.
if [ ! -f "$CLAUDE_DIR/lessons/learned-patterns.md" ] \
   && [ -f "$SCRIPT_DIR/lessons/learned-patterns.md" ]; then
  cp "$SCRIPT_DIR/lessons/learned-patterns.md" "$CLAUDE_DIR/lessons/learned-patterns.md"
  echo "  Seeded lessons/learned-patterns.md from repo (deferred corpus)"
fi


# --- Phase 6.5: Remove retired context templates from old installs ---
# The ROUTER context-router and pattern-index templates are retired (Boris v3):
# native auto-memory (MEMORY.md index + lazy topic files) replaces keyword
# routing. Clean them off machines upgrading from v2.
echo "--- Phase 6.5: Remove retired context templates ---"
if [ -d "$CLAUDE_DIR/context" ]; then
  rm -rf "$CLAUDE_DIR/context"
  echo "  Removed retired ~/.claude/context/ (ROUTER, patterns index)"
else
  echo "  No retired context templates to remove"
fi

# --- Phase 7: Install CLAUDE.md + migrate lessons to the rules file ---
echo "--- Phase 7: CLAUDE.md + lesson migration ---"

# Boris v3.1: lessons live in ~/.claude/lessons/learned-patterns.md (deferred), not CLAUDE.md.
# The version stamp is an HTML comment ("boris-version: 3") because users edit
# prose headings; the stamp is the one line they're told not to remove.

# Rebuild CLAUDE.md from the repo template into $2, preserving user-authored
# content from the old-file snapshot in $1: every top-level section whose
# heading is not template-owned (the known-heading list below) is carried
# over, appended after the template. Shared by the pre-v3 migration and the
# v3->v3 template re-sync so both paths preserve the same guarantees. Sets
# CARRYOVER to a temp file holding the carried sections; the caller reports
# via report_carryover (which removes it) or removes it directly.
render_claude_md() {
  CARRYOVER="$(mktemp)"
  # fence tracking: a "# comment" line inside a ```code block``` (the Quick
  # Reference section is full of them) is NOT a section heading — without
  # this, template code-block comments get carried over as "custom" sections.
  awk '
    /^```/ { fence = !fence }
    /^# / && !fence {
      keep = 1
      # Retired headings stay listed forever: an old machine still carries the
      # section, and dropping it from this list turns template content into
      # "user custom" content that gets appended on every re-run.
      #   Quick Reference       -> retired in v3.1, replaced by Orchestration defaults
      if ($0 ~ /^# (Session Boot|User Preferences|Orchestration defaults|Quick Reference|Workflow Orchestration|Memory Bank|Core Principles|Learned Patterns|Rules)/) keep = 0
    }
    keep { print }
  ' "$1" > "$CARRYOVER"
  cp "$SCRIPT_DIR/CLAUDE.md" "$2"
  if [ -s "$CARRYOVER" ]; then
    { echo ""; cat "$CARRYOVER"; } >> "$2"
  fi
}

# $1 = the old-file snapshot render_claude_md was given.
report_carryover() {
  if [ -s "$CARRYOVER" ]; then
    echo "  Carried over custom section(s) from your old CLAUDE.md:"
    grep '^# ' "$CARRYOVER" | sed 's/^/    /'
  fi
  rm -f "$CARRYOVER"
  # @imports inside template-owned sections do not survive the replacement
  if grep -qE '^\s*@[~./]' "$1" && ! grep -qE '^\s*@[~./]' "$CLAUDE_DIR/CLAUDE.md"; then
    echo "  WARNING: your old CLAUDE.md contained @import lines that were not carried over."
    echo "  Re-add them from the backup if still needed: $BACKUP_DIR/CLAUDE.md"
  fi
}

if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && ! grep -q "boris-version: 3" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
  # Pre-v3 (or pre-Boris) CLAUDE.md: migrate its Learned Patterns into the
  # local rules file BEFORE replacing the structure. The merge is the ungated
  # Repo->Local direction (REPO_FILE = the old file snapshot, never the public
  # repo), so private/untagged lessons are preserved locally and never leak.
  SNAPSHOT="$(mktemp)"
  cp "$CLAUDE_DIR/CLAUDE.md" "$SNAPSHOT"
  MIGRATION_OK=true
  if grep -q '^# Learned Patterns' "$SNAPSHOT" 2>/dev/null; then
    mkdir -p "$CLAUDE_DIR/lessons"
    [ -f "$CLAUDE_DIR/lessons/learned-patterns.md" ] || printf '# Learned Patterns\n' > "$CLAUDE_DIR/lessons/learned-patterns.md"
    if LOCAL_FILE="$CLAUDE_DIR/lessons/learned-patterns.md" REPO_FILE="$SNAPSHOT" \
       "$SCRIPT_DIR/sync-lessons.sh" >/dev/null 2>&1; then
      echo "  Migrated Learned Patterns from old CLAUDE.md into lessons/learned-patterns.md"
    else
      MIGRATION_OK=false
    fi
  fi

  if [ "$MIGRATION_OK" = "true" ]; then
    render_claude_md "$SNAPSHOT" "$CLAUDE_DIR/CLAUDE.md"
    report_carryover "$SNAPSHOT"
    echo "  Installed slim Boris v3 CLAUDE.md (old version in backup: $BACKUP_DIR)"
  else
    echo "  ERROR: lesson migration FAILED — your existing CLAUDE.md was left unchanged."
    echo "  No lessons were lost. Fix the issue (run ./sync-lessons.sh manually to see the"
    echo "  error with LOCAL_FILE=$CLAUDE_DIR/lessons/learned-patterns.md) and re-run install.sh."
  fi
  rm -f "$SNAPSHOT"

# Index LAST: Phase 7 may have just migrated lessons into the corpus, and a stale index
# makes deferred lessons invisible.
if [ -x "$SCRIPT_DIR/scripts/reindex-lessons.sh" ]; then
  "$SCRIPT_DIR/scripts/reindex-lessons.sh" || true
fi
elif [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  Installed CLAUDE.md (fresh install)"
else
  # Already stamped v3 — but template content still moves WITHIN v3, so a
  # stamp-only check would strand template updates on installed machines.
  # Rebuild (current template + carried-over custom sections) and compare:
  # identical means nothing to do; different means the template changed since
  # this machine last installed, so refresh it. Custom sections, @import
  # warning, and the Phase 1 backup give the same guarantees as the
  # migration path. No minor version stamp needed: the content comparison
  # is self-maintaining.
  SNAPSHOT="$(mktemp)"
  cp "$CLAUDE_DIR/CLAUDE.md" "$SNAPSHOT"
  CANDIDATE="$(mktemp)"
  render_claude_md "$SNAPSHOT" "$CANDIDATE"
  if cmp -s "$CANDIDATE" "$CLAUDE_DIR/CLAUDE.md"; then
    echo "  CLAUDE.md already at Boris v3 (template current)"
    rm -f "$CARRYOVER"
  else
    cp "$CANDIDATE" "$CLAUDE_DIR/CLAUDE.md"
    echo "  Refreshed Boris v3 CLAUDE.md template sections (old version in backup: $BACKUP_DIR)"
    report_carryover "$SNAPSHOT"
  fi
  rm -f "$SNAPSHOT" "$CANDIDATE"
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
echo "  - rules/ (git-safety, workflow, documentation-channels, learned-patterns hot core + index)"
echo "  - settings.json (merged with hooks)"
echo "  - CLAUDE.md (slim v3 core; lessons deferred to ~/.claude/lessons/learned-patterns.md)"
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
echo "  ./sync-lessons.sh && git add lessons/learned-patterns.md && git commit -m 'sync lessons' && git push"
