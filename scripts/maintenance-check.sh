#!/usr/bin/env bash
# maintenance-check.sh — self-audit for the claude-workflow repo.
#
# Catches the exact drift this repo suffered before ("15 agents, 23 commands"
# in the docs while reality had moved on): it recomputes the real counts of
# agents / skills / hooks / community agents and compares them to the numbers
# the README and CHEATSHEET claim, and runs drift-check on any Memory Bank.
# Zero AI tokens, pure bash 3.2. Meant to run weekly on a schedule (see
# --install-cron) and also usable ad hoc.
#
# Usage:
#   bash scripts/maintenance-check.sh              # audit, print report
#   bash scripts/maintenance-check.sh --quiet      # one-line status only
#   bash scripts/maintenance-check.sh --install-cron    # weekly local cron
#   bash scripts/maintenance-check.sh --uninstall-cron
#
# Exit: 0 = clean, 1 = drift found (so cron mail / a wrapper can alert).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUIET=false
FINDINGS=0

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=true ;;
    --install-cron)   exec "$0" __install_cron ;;
    --uninstall-cron) exec "$0" __uninstall_cron ;;
  esac
done

# ─── Cron install/uninstall (safe temp-file pattern; never grep -v under set -e) ───
CRON_TAG="# claude-workflow-maintenance"
if [ "${1:-}" = "__install_cron" ]; then
  LINE="0 9 * * 1 cd $REPO_DIR && /bin/bash scripts/maintenance-check.sh --quiet >> $REPO_DIR/.claude/audit/maintenance.log 2>&1 $CRON_TAG"
  mkdir -p "$REPO_DIR/.claude/audit"
  TMP="$(mktemp)"
  crontab -l 2>/dev/null | grep -vF "$CRON_TAG" > "$TMP" || true
  echo "$LINE" >> "$TMP"
  crontab "$TMP" && rm -f "$TMP"
  echo "Installed weekly maintenance cron (Mondays 09:00). Verify: crontab -l"
  echo "Log: $REPO_DIR/.claude/audit/maintenance.log"
  exit 0
fi
if [ "${1:-}" = "__uninstall_cron" ]; then
  TMP="$(mktemp)"
  crontab -l 2>/dev/null | grep -vF "$CRON_TAG" > "$TMP" || true
  crontab "$TMP" && rm -f "$TMP"
  echo "Removed maintenance cron. Verify: crontab -l"
  exit 0
fi

# ─── Count helpers ───
# Pull the count column (field 3) from a "| Label | N | ... |" markdown row.
doc_num() { # file  label
  grep -m1 "^| $2 " "$1" 2>/dev/null | awk -F'|' '{print $3}' | grep -oE '[0-9]+' | head -1
}
# Pull the Nth number from a row (for "44 active / 105 vendored").
doc_num_nth() { # file  label  n
  grep -m1 "^| $2 " "$1" 2>/dev/null | grep -oE '[0-9]+' | sed -n "${3}p"
}
count_active_manifest() {
  sed 's/#.*//' "$REPO_DIR/agents/community/MANIFEST.txt" 2>/dev/null \
    | while IFS= read -r l; do s=$(printf '%s' "$l" | xargs); [ -n "$s" ] && echo x; done | wc -l | tr -d ' '
}

report() { # label  actual  claimed  where
  if [ -z "$3" ]; then
    $QUIET || echo "  SKIP  $1 — no count found in $4"
    return
  fi
  if [ "$2" = "$3" ]; then
    $QUIET || echo "  OK    $1: $2 (matches $4)"
  else
    $QUIET || echo "  DRIFT $1: actual $2 but $4 says $3"
    FINDINGS=$((FINDINGS + 1))
  fi
}

$QUIET || echo "=== claude-workflow maintenance check ==="
$QUIET || echo "Repo: $REPO_DIR"

# Actual counts
CORE=$(ls "$REPO_DIR/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
VENDORED=$(ls "$REPO_DIR/agents/community/"*.md 2>/dev/null | wc -l | tr -d ' ')
ACTIVE=$(count_active_manifest)
SKILLS=$(ls -d "$REPO_DIR/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
HOOKS=$(ls "$REPO_DIR/scripts/"hook-*.sh 2>/dev/null | wc -l | tr -d ' ')

R="$REPO_DIR/README.md"; C="$REPO_DIR/CHEATSHEET.md"

$QUIET || echo "-- README doc-count audit --"
report "core agents"        "$CORE"     "$(doc_num "$R" 'Core agents')"          "README"
report "skills"             "$SKILLS"   "$(doc_num "$R" 'Skills')"               "README"
report "hook scripts"       "$HOOKS"    "$(doc_num "$R" 'Hook scripts')"         "README"
report "community active"   "$ACTIVE"   "$(doc_num_nth "$R" 'Community agents' 1)" "README"
report "community vendored" "$VENDORED" "$(doc_num_nth "$R" 'Community agents' 2)" "README"

$QUIET || echo "-- CHEATSHEET heading audit --"
CHEAT_CORE=$(grep -m1 '^## Core Agents' "$C" 2>/dev/null | grep -oE '[0-9]+' | head -1)
report "cheatsheet core agents" "$CORE" "$CHEAT_CORE" "CHEATSHEET"

# Charter template guard — skills/task-branch/SKILL.md seeds every
# .claude/task-context.md; if its template loses a charter heading, every new
# task starts without a source of truth and drift-check WARNs on each one.
# Skipped (like the doc-count SKIPs) when the file is absent — fixture repos
# without skills/ shouldn't fail; the real repo always ships it.
TB="$REPO_DIR/skills/task-branch/SKILL.md"
$QUIET || echo "-- Charter template guard (task-branch) --"
if [ -f "$TB" ]; then
  for H in "Objective" "Non-goals" "Acceptance"; do
    if grep -qE "^## ${H}([[:space:]]|\$)" "$TB"; then
      $QUIET || echo "  OK    task-branch template has '## $H'"
    else
      $QUIET || echo "  DRIFT skills/task-branch/SKILL.md template missing '## $H' charter heading"
      FINDINGS=$((FINDINGS + 1))
    fi
  done
else
  $QUIET || echo "  SKIP  charter template — no skills/task-branch/SKILL.md in this repo"
fi

# Memory Bank drift — ADVISORY only (does not affect exit code). The repo's own
# .claude/memory/ is gitignored working scratch and never ships; and drift-check
# already runs at every session boundary and post-commit. This is just a heads-up.
if [ -d "$REPO_DIR/.claude/memory" ]; then
  DOUT=$(cd "$REPO_DIR" && bash scripts/drift-check.sh --quiet 2>/dev/null || echo "")
  DSCORE=$(echo "$DOUT" | grep -oE 'Score: [0-9]+' | grep -oE '[0-9]+' || true)
  if [ -n "$DSCORE" ]; then
    $QUIET || echo "-- Memory Bank (advisory) --"
    if [ "$DSCORE" -lt 80 ]; then
      $QUIET || echo "  note  Memory Bank score $DSCORE < 80 (advisory — run /drift-check if this is a real project, not local scratch)"
    else
      $QUIET || echo "  OK    Memory Bank score $DSCORE"
    fi
  fi
fi

if $QUIET; then
  if [ "$FINDINGS" -eq 0 ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) maintenance: clean"
  else
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) maintenance: $FINDINGS drift finding(s) — run scripts/maintenance-check.sh"
  fi
else
  echo ""
  if [ "$FINDINGS" -eq 0 ]; then
    echo "Clean — docs match reality."
  else
    echo "$FINDINGS drift finding(s). Update the doc counts (or the files), then re-run."
  fi
fi

[ "$FINDINGS" -eq 0 ]
