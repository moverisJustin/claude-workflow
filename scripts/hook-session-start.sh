#!/usr/bin/env bash
# Hook: SessionStart
# Auto-load compact Memory Bank context or detect new projects
# Context impact: YES — stdout is injected into context window
# HARD CAP: 1500 characters maximum output

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="$PROJECT_DIR/.claude/project-config.json"
MEMORY_DIR="$PROJECT_DIR/.claude/memory"
TASK_CONTEXT="$PROJECT_DIR/.claude/task-context.md"
MAX_CHARS=1500

# ─── Scenario B: New / Unconfigured Project ───
if [ ! -f "$CONFIG_FILE" ]; then
  # Check for existing signals
  HAS_GIT="no"
  GIT_REMOTE=""
  HAS_MEMORY="no"

  if [ -d "$PROJECT_DIR/.git" ]; then
    HAS_GIT="yes"
    GIT_REMOTE=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "none")
  fi

  if [ -d "$MEMORY_DIR" ] && [ -f "$MEMORY_DIR/projectContext.md" ]; then
    HAS_MEMORY="yes"
  fi

  # Only prompt for init if there's no Memory Bank
  # (If Memory Bank exists but no config, create config silently later)
  if [ "$HAS_MEMORY" = "no" ]; then
    cat <<PROMPT
[New Project Detected]
Directory: $PROJECT_DIR
Git repo: $HAS_GIT (remote: $GIT_REMOTE)

This project has no Memory Bank yet. Ask the user:
1. Should this project use git? (If yes and no repo exists, offer git init + gh repo create)
2. Brief description of what this project is?
Then run /memory-init and save git preference to .claude/project-config.json.
PROMPT
    exit 0
  fi

  # Memory Bank exists but no config — treat as established, suggest creating config
  echo "[Session Context — config missing, run /memory-init to create .claude/project-config.json]"
fi

# ─── Read project config ───
GIT_ENABLED="true"
if [ -f "$CONFIG_FILE" ]; then
  GIT_ENABLED=$(python3 -c "import json; print(str(json.load(open('$CONFIG_FILE')).get('git_enabled', True)).lower())" 2>/dev/null || echo "true")
fi

# ─── Scenario A/C: Established Project ───
OUTPUT=""

# Project name from first heading in projectContext.md
if [ -f "$MEMORY_DIR/projectContext.md" ]; then
  PROJECT_NAME=$(grep -m1 '^#\|^##\|^\*\*Name\*\*' "$MEMORY_DIR/projectContext.md" 2>/dev/null | head -1 | sed 's/^#* *//' | head -c 80)
else
  PROJECT_NAME=$(basename "$PROJECT_DIR")
fi

# Git info (only if enabled)
BRANCH_INFO=""
if [ "$GIT_ENABLED" = "true" ] && [ -d "$PROJECT_DIR/.git" ]; then
  BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "detached")
  DIRTY=$(git -C "$PROJECT_DIR" status --short 2>/dev/null | wc -l | tr -d ' ')
  if [ "$DIRTY" -gt 0 ]; then
    BRANCH_INFO="Branch: $BRANCH ($DIRTY uncommitted) | Git: enabled"
  else
    BRANCH_INFO="Branch: $BRANCH (clean) | Git: enabled"
  fi
else
  BRANCH_INFO="Git: disabled"
fi

# Last session context (first meaningful lines from activeContext.md)
LAST_CONTEXT=""
if [ -f "$MEMORY_DIR/activeContext.md" ]; then
  # Get lines after "## Current" or "## Recent" headings, skip blanks
  LAST_CONTEXT=$(grep -A3 '## \(Current\|Recent\)' "$MEMORY_DIR/activeContext.md" 2>/dev/null | grep -v '^##' | grep -v '^--$' | grep -v '^$' | head -3 | sed 's/^- //' | head -c 300)
fi

# Task context (if on a feature branch)
TASK_INFO=""
if [ -f "$TASK_CONTEXT" ]; then
  TASK_INFO=$(grep -A2 '## Objective\|## Goal\|## Task' "$TASK_CONTEXT" 2>/dev/null | grep -v '^##' | grep -v '^--$' | grep -v '^$' | head -2 | head -c 200)
fi

# Compose output
{
  echo "[Auto-loaded Session Context]"
  echo "Project: $PROJECT_NAME | $BRANCH_INFO"
  [ -n "$LAST_CONTEXT" ] && echo "Last: $LAST_CONTEXT"
  [ -n "$TASK_INFO" ] && echo "Task: $TASK_INFO"
  echo "Run /session-start for full context."
} | head -c "$MAX_CHARS"

exit 0
