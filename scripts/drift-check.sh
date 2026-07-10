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

# --- Reference-resolution helpers (used by check_paths & friends) ---

# Pre-v3 Memory Bank files are frozen chronological logs pending /memory-migrate.
# They legitimately reference historical and cross-repo files, so validating
# them floods the score with false positives (they were 208 of moveris_cluster's
# 272 errors). Session state is carried by native auto-memory now.
is_retired_memory_file() {
  case "$1" in
    activeContext.md|progress.md|sessionHistory.md|ROUTER.md|patterns.md) return 0 ;;
  esac
  return 1
}

# A dotted token only counts as a file reference when its extension plausibly
# names a project file. Everything else is prose: domains (moveris.com), emails
# (justin.r.keene), dotted identifiers (cv2.VideoCapture, moveris.generate.api),
# sizes (1.9T), systemd units (suspend.target, enp0s1.network). Deliberately
# absent: .db/.log/.env (runtime artifacts, gitignored — never verifiable) and
# systemd unit extensions (.service/.target/.mount — unit names, not files).
FILE_EXT_ALLOWLIST="md markdown sh bash py ipynb yml yaml json js mjs cjs ts tsx jsx sql toml ini cfg conf txt csv tsv html css scss rs go java rb php c h cpp hpp xml svg proto tf lock"

# Well-known product names that end in an allowlisted extension but are prose.
PRODUCT_NAMES="Next.js Node.js Vue.js React.js Three.js D3.js Express.js Nest.js Alpine.js Chart.js Ember.js"

IS_GIT=false
git rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=true

REPO_FILES=""
SIBLING_FILES=""
SIBLINGS_LOADED=false

build_repo_files() {
  if $IS_GIT; then
    REPO_FILES=$(git ls-files 2>/dev/null || true)
  else
    REPO_FILES=$(find . -type f -not -path './.git/*' 2>/dev/null | sed 's|^\./||' || true)
  fi
}

# Memory legitimately references files in sibling repo checkouts (the other
# projects the work touches). Loaded lazily — only when a reference fails
# repo-local resolution. Worktree-aware: resolves siblings of the MAIN
# checkout's parent dir, not the worktree's.
load_sibling_files() {
  $SIBLINGS_LOADED && return 0
  SIBLINGS_LOADED=true
  local root common parent d
  root=$(pwd)
  if $IS_GIT; then
    common=$(git rev-parse --git-common-dir 2>/dev/null || echo "$root/.git")
    root=$(cd "$(dirname "$common")" 2>/dev/null && pwd) || root=$(pwd)
  fi
  parent=$(dirname "$root")
  for d in "$parent"/*/; do
    [ -d "${d}.git" ] || continue
    [ "${d%/}" = "$root" ] && continue
    SIBLING_FILES="${SIBLING_FILES}
$(git -C "$d" ls-files 2>/dev/null || true)"
  done
}

# The repo's own committed docs (*.md outside .claude/) naming the same
# artifact means the Memory Bank agrees with the repo — e.g. a bootstrap
# script that lives on a cluster node but is described in an ADR. Not drift.
doc_corpus_has() {
  if $IS_GIT; then
    git grep -qF "$1" -- '*.md' ':(exclude).claude' 2>/dev/null
  else
    grep -rqF --include='*.md' --exclude-dir='.claude' "$1" . 2>/dev/null
  fi
}

# resolve_ref PATH → 0 when the reference resolves anywhere legitimate:
#   1. as-is from the repo root
#   2. by suffix/basename against the repo file list (docs/storage.md
#      referenced as plain storage.md, checks/restore_test.sh under
#      data-platform/) — subsumes "try docs/, scripts/, monitoring/"
#   3. against sibling repo checkouts' tracked files (cross-repo references)
#   4. named in the repo's own committed docs (off-machine artifacts)
resolve_ref() {
  local path="$1" esc
  [ -e "$path" ] && return 0
  esc="${path//./\\.}"
  if [ -n "$REPO_FILES" ]; then
    grep -qE "(^|/)${esc}\$" <<< "$REPO_FILES" && return 0
  fi
  load_sibling_files
  if [ -n "$SIBLING_FILES" ]; then
    grep -qE "(^|/)${esc}\$" <<< "$SIBLING_FILES" && return 0
  fi
  doc_corpus_has "$path"
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
  # Surviving Memory Bank files + the committed task-context. Deliberately NOT
  # CLAUDE.md or rules/: those reference files by bare basename and by
  # installed-location paths (~/.claude/rules/*, native MEMORY.md) that don't
  # exist relative to the project root, so scanning them floods the score with
  # false-positive dead paths.
  build_repo_files
  for md_file in "$MEMORY_DIR"/*.md .claude/task-context.md; do
    [ -f "$md_file" ] || continue
    basename=$(basename "$md_file")
    is_retired_memory_file "$basename" && continue
    # One grep pass per file (output "linenum:match"), deduped, file order preserved.
    # IMPORTANT: a single process substitution PER FILE — not one per line — because
    # bash 3.2 (stock on macOS) segfaults after a few hundred process substitutions.
    while IFS=: read -r line_num path; do
      [ -z "$path" ] && continue
      # Skip common false positives
      [[ "$path" == http* ]] && continue
      [[ "$path" == "#"* ]] && continue
      [[ "$path" == ".claude/memory/"* ]] && continue
      [[ "$path" == *"*"* ]] && continue   # glob patterns
      [[ "$path" == *"["* ]] && continue   # markdown placeholders
      [[ "$path" == *"{"* ]] && continue   # template variables
      [[ "$path" == "/"* ]] && continue    # absolute paths
      [[ "$path" == "~"* ]] && continue    # home paths (~/.claude/... — not project-relative)
      [[ "$path" == -* ]] && continue          # CLI flags: --collector.systemd
      [[ "$path" == x-systemd* ]] && continue  # mount options: x-systemd.automount
      # Plausibility gate: only tokens with a known file extension are file
      # references; everything else is prose (see FILE_EXT_ALLOWLIST above).
      local ext="${path##*.}"
      case " $FILE_EXT_ALLOWLIST " in
        *" $ext "*) ;;
        *) continue ;;
      esac
      case " $PRODUCT_NAMES " in
        *" $path "*) continue ;;
      esac
      # Strip relative prefixes so docs written from a subdir context
      # (../scripts/foo.py) still resolve by suffix against the repo tree.
      path="${path#./}"
      while [[ "$path" == ../* ]]; do path="${path#../}"; done
      if ! resolve_ref "$path"; then
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

  # task-context.md is the only surviving file that names branches
  # (activeContext/progress are retired — native auto-memory carries session state).
  for md_file in .claude/task-context.md; do
    [ -f "$md_file" ] || continue
    basename=$(basename "$md_file")
    # Look for branch-like references: feature/xxx, fix/xxx, task/xxx, claude/xxx
    # One grep pass per file (see check_paths re: bash 3.2 / process substitution).
    while IFS=: read -r line_num branch_ref; do
      [ -z "$branch_ref" ] && continue
      # Skip filesystem paths that look like branch refs: ".claude/rules",
      # "~/.claude/context", etc. all match "claude/..." but are paths, not
      # branches. If the ref appears in the file preceded by a dot, it's a path.
      if grep -qF ".$branch_ref" "$md_file"; then continue; fi
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

    # Skip durable reference files: projectContext (project identity) and
    # decisionLog (historical ADRs) legitimately don't change for weeks.
    # conventions.md should grow, so it stays checked. Retired pre-v3 files
    # are frozen history — their age isn't drift.
    [[ "$basename" == "projectContext.md" || "$basename" == "decisionLog.md" ]] && continue
    is_retired_memory_file "$basename" && continue

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
      [[ "$basename" == "projectContext.md" || "$basename" == "decisionLog.md" ]] && continue
      is_retired_memory_file "$basename" && continue

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
    is_retired_memory_file "$basename" && continue
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
      is_retired_memory_file "$basename" && continue
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
