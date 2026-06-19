#!/usr/bin/env bash
# drift-check.sh — Validate Memory Bank accuracy against codebase reality
# Zero AI tokens. Pure static analysis. Runs in any project.
#
# Usage:
#   bash .claude/scripts/drift-check.sh           # Full report
#   bash .claude/scripts/drift-check.sh --quiet   # One-line score only
#   bash .claude/scripts/drift-check.sh --json    # JSON output

set -euo pipefail

# --- Configuration ---
MEMORY_DIR=".claude/memory"
SCORE=100
ERRORS=0
WARNINGS=0
INFOS=0
FINDINGS=()
QUIET=false
JSON_OUTPUT=false

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=true ;;
    --json) JSON_OUTPUT=true ;;
  esac
done

# --- Helpers ---
add_finding() {
  local severity="$1" file="$2" line="$3" msg="$4"
  case "$severity" in
    ERROR)   SCORE=$((SCORE - 10)); ERRORS=$((ERRORS + 1)) ;;
    WARN)    SCORE=$((SCORE - 3));  WARNINGS=$((WARNINGS + 1)) ;;
    INFO)    SCORE=$((SCORE - 1));  INFOS=$((INFOS + 1)) ;;
  esac
  if [ $SCORE -lt 0 ]; then SCORE=0; fi
  FINDINGS+=("${severity}|${file}|${line}|${msg}")
}

# --- Pre-flight ---
if [ ! -d "$MEMORY_DIR" ]; then
  if $QUIET; then
    echo "[DRIFT] No Memory Bank found"
    exit 0
  fi
  echo "No Memory Bank found at $MEMORY_DIR"
  echo "Run /memory-init to create one."
  exit 0
fi

# --- Checker 1: Dead File Paths ---
# Finds file paths referenced in Memory Bank .md files that don't exist on disk
check_paths() {
  local md_file line_num path basename
  for md_file in "$MEMORY_DIR"/*.md "$MEMORY_DIR"/patterns/*.md .claude/task-context.md; do
    [ -f "$md_file" ] || continue
    basename=$(basename "$md_file")
    # One grep pass per file (output "linenum:match"), deduped, file order preserved.
    # IMPORTANT: a single process substitution PER FILE — not one per line — because
    # bash 3.2 (stock on macOS) segfaults after a few hundred process substitutions.
    while IFS=: read -r line_num path; do
      [ -z "$path" ] && continue
      # Skip common false positives
      [[ "$path" == http* ]] && continue
      [[ "$path" == "#"* ]] && continue
      [[ "$path" == ".claude/memory/"* ]] && continue
      [[ "$path" == "patterns/"* ]] && continue
      [[ "$path" == *"*"* ]] && continue   # glob patterns
      [[ "$path" == *"["* ]] && continue   # markdown placeholders
      [[ "$path" == *"{"* ]] && continue   # template variables
      [[ "$path" == "/"* ]] && continue    # absolute paths
      # Only check paths that look like real file references (have an extension)
      if [[ "$path" == *"."* ]] && [ ! -e "$path" ]; then
        add_finding "ERROR" "$basename" "$line_num" "references $path (file not found)"
      fi
    done < <(grep -noE '[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]+' "$md_file" | awk '!seen[$0]++')
  done
}

# --- Checker 2: Dead Branch References ---
# Finds branch names in progress/task-context that no longer exist
check_branches() {
  # Skip if not a git repo
  git rev-parse --git-dir > /dev/null 2>&1 || return 0

  local branches md_file line_num branch_ref basename
  branches=$(git branch -a 2>/dev/null | sed 's/^[* ]*//' | sed 's|remotes/origin/||' | sort -u)

  for md_file in "$MEMORY_DIR"/progress.md "$MEMORY_DIR"/activeContext.md .claude/task-context.md; do
    [ -f "$md_file" ] || continue
    basename=$(basename "$md_file")
    # Look for branch-like references: feature/xxx, fix/xxx, task/xxx, claude/xxx
    # One grep pass per file (see check_paths re: bash 3.2 / process substitution).
    while IFS=: read -r line_num branch_ref; do
      [ -z "$branch_ref" ] && continue
      if ! printf '%s\n' "$branches" | grep -qF "$branch_ref"; then
        add_finding "WARN" "$basename" "$line_num" "references branch $branch_ref (branch not found)"
      fi
    done < <(grep -noE '(feature|fix|task|claude|hotfix|release)/[a-zA-Z0-9_.-]+' "$md_file" | awk '!seen[$0]++')
  done
}

# --- Checker 3: Missing Dependencies ---
# Finds package names claimed in Memory Bank but missing from manifest
check_dependencies() {
  local manifest="" md_file line_num pkg basename

  if [ -f "package.json" ]; then
    manifest="package.json"
  elif [ -f "requirements.txt" ]; then
    manifest="requirements.txt"
  elif [ -f "pyproject.toml" ]; then
    manifest="pyproject.toml"
  elif [ -f "Cargo.toml" ]; then
    manifest="Cargo.toml"
  elif [ -f "go.mod" ]; then
    manifest="go.mod"
  else
    return 0  # No manifest found, skip
  fi

  # Look for dependency-like mentions in conventions.md and projectContext.md
  for md_file in "$MEMORY_DIR"/conventions.md "$MEMORY_DIR"/projectContext.md; do
    [ -f "$md_file" ] || continue
    basename=$(basename "$md_file")
    # One grep pass per file (see check_paths re: bash 3.2 / process substitution).
    while IFS=: read -r line_num pkg; do
      [ -z "$pkg" ] && continue
      # Skip common non-package words
      [[ "$pkg" == "true" || "$pkg" == "false" || "$pkg" == "null" || "$pkg" == "none" ]] && continue
      [[ ${#pkg} -lt 2 ]] && continue
      # Check if package exists in manifest
      if ! grep -qi "$pkg" "$manifest" 2>/dev/null; then
        add_finding "WARN" "$basename" "$line_num" "references package \`$pkg\` (not found in $manifest)"
      fi
    done < <(grep -noE '`[a-zA-Z0-9@/_-]+`' "$md_file" | tr -d '`' | awk '!seen[$0]++')
  done
}

# --- Checker 4: Staleness ---
# Finds Memory Bank files not updated recently
check_staleness() {
  local now
  now=$(date +%s)
  local stale_days=30

  for md_file in "$MEMORY_DIR"/*.md; do
    [ -f "$md_file" ] || continue
    local basename
    basename=$(basename "$md_file")

    # Skip sessionHistory (it's append-only and can be old)
    [[ "$basename" == "sessionHistory.md" ]] && continue

    local mod_time
    if [[ "$(uname)" == "Darwin" ]]; then
      mod_time=$(stat -f %m "$md_file")
    else
      mod_time=$(stat -c %Y "$md_file")
    fi

    local age_days=$(( (now - mod_time) / 86400 ))
    if [ "$age_days" -gt "$stale_days" ]; then
      add_finding "INFO" "$basename" "0" "last updated ${age_days} days ago (>${stale_days}d threshold)"
    fi
  done

  # Also check by commit count if in a git repo
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local commit_count
    for md_file in "$MEMORY_DIR"/*.md; do
      [ -f "$md_file" ] || continue
      local basename
      basename=$(basename "$md_file")
      [[ "$basename" == "sessionHistory.md" ]] && continue

      # Count commits since file was last modified
      local last_commit
      last_commit=$(git log -1 --format="%H" -- "$md_file" 2>/dev/null || echo "")
      if [ -n "$last_commit" ]; then
        commit_count=$(git rev-list --count "$last_commit"..HEAD 2>/dev/null || echo "0")
        if [ "$commit_count" -gt 50 ]; then
          add_finding "INFO" "$basename" "0" "${commit_count} commits since last update (>50 threshold)"
        fi
      fi
    done
  fi
}

# --- Checker 5: Command References ---
# Finds CLI commands referenced in Memory Bank that don't resolve
check_commands() {
  # Only check if package.json exists (npm scripts)
  [ -f "package.json" ] || return 0

  local md_file line_num script target basename
  for md_file in "$MEMORY_DIR"/*.md; do
    [ -f "$md_file" ] || continue
    basename=$(basename "$md_file")
    # One grep pass per file (see check_paths re: bash 3.2 / process substitution).
    while IFS=: read -r line_num script; do
      [ -z "$script" ] && continue
      if ! grep -q "\"$script\"" package.json 2>/dev/null; then
        add_finding "WARN" "$basename" "$line_num" "references npm script \`$script\` (not in package.json scripts)"
      fi
    done < <(grep -noE 'npm run [a-zA-Z0-9:_-]+' "$md_file" | sed 's/npm run //' | awk '!seen[$0]++')
  done

  # Check Makefile targets if Makefile exists
  if [ -f "Makefile" ]; then
    for md_file in "$MEMORY_DIR"/*.md; do
      [ -f "$md_file" ] || continue
      basename=$(basename "$md_file")
      while IFS=: read -r line_num target; do
        [ -z "$target" ] && continue
        if ! grep -qE "^${target}:" Makefile 2>/dev/null; then
          add_finding "WARN" "$basename" "$line_num" "references make target \`$target\` (not in Makefile)"
        fi
      done < <(grep -noE 'make [a-zA-Z0-9_-]+' "$md_file" | sed 's/make //' | awk '!seen[$0]++')
    done
  fi
}

# --- Run All Checkers ---
check_paths
check_branches
check_dependencies
check_staleness
check_commands

# --- Output ---
if $JSON_OUTPUT; then
  echo "{"
  echo "  \"score\": $SCORE,"
  echo "  \"errors\": $ERRORS,"
  echo "  \"warnings\": $WARNINGS,"
  echo "  \"infos\": $INFOS,"
  echo "  \"findings\": ["
  first=true
  for f in "${FINDINGS[@]+"${FINDINGS[@]}"}"; do
    IFS='|' read -r sev file line msg <<< "$f"
    if $first; then first=false; else echo ","; fi
    printf '    {"severity": "%s", "file": "%s", "line": %s, "message": "%s"}' "$sev" "$file" "$line" "$msg"
  done
  echo ""
  echo "  ]"
  echo "}"
  exit 0
fi

if $QUIET; then
  echo "[DRIFT] Score: ${SCORE}/100 (${ERRORS} errors, ${WARNINGS} warnings, ${INFOS} info)"
  exit 0
fi

# Full report
echo "========================================"
echo "  DRIFT CHECK — Memory Bank Validation"
echo "========================================"
echo ""
echo "Score: ${SCORE}/100"
echo "  Errors:   ${ERRORS} (-10 each)"
echo "  Warnings: ${WARNINGS} (-3 each)"
echo "  Info:     ${INFOS} (-1 each)"
echo ""

if [ ${#FINDINGS[@]} -eq 0 ]; then
  echo "No drift detected. Memory Bank is in sync with codebase."
else
  echo "Findings:"
  echo "--------"
  for f in "${FINDINGS[@]}"; do
    IFS='|' read -r sev file line msg <<< "$f"
    if [ "$line" = "0" ]; then
      printf "  %-5s  %-25s  %s\n" "$sev" "$file" "$msg"
    else
      printf "  %-5s  %-25s  line %-4s  %s\n" "$sev" "$file" "$line" "$msg"
    fi
  done
fi
echo ""
echo "Run /drift-check for AI-assisted fixes."
