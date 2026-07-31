#!/usr/bin/env bash
# resolve-base-branch.sh — work out which branch THIS repo actually branches off.
#
# The workflow used to hardcode `main` everywhere. That is wrong for a large
# minority of real repos: a survey of 55 active Moveris repos found three
# models — main (43), master (6), develop+main gitflow (6) — so `/task-branch`
# was running `git checkout main` in repos whose branch is `master`, and
# treating gitflow repos as if only `main` were protected.
#
# Two values come out of this, and they are NOT the same thing:
#
#   base_branch        where a NEW feature branch starts (main | master | develop)
#   protected_branches every branch that RECEIVES PRs, union the default branch.
#                      In gitflow both `develop` and `main` are protected, so
#                      "never work on main" has to become "never work on a
#                      protected branch" (plural).
#
# Resolution precedence, highest first:
#   1. base_branch in .claude/project-config.json     — explicit always wins
#   2. modal baseRefName over recent merged PRs       — empirical; got all 5
#      (`gh pr list --state merged --json baseRefName`)  sampled repos right
#   3. gh repo view --json defaultBranchRef           — repos with no PR history
#   4. whichever of main/master actually exists       — no gh, or offline
#
# Steps 2-3 need `gh`; without it we degrade to 4 rather than guessing. The
# resolved answer is CACHED into .claude/project-config.json so the network
# calls happen once per repo, not once per branch creation. The caller is
# expected to show the evidence and confirm before the first cache write —
# see --explain.
#
# Usage:
#   resolve-base-branch.sh [--base|--protected|--explain|--json]
#                          [--no-cache] [--refresh] [--dir DIR]
#     --base       print the base branch only (default)
#     --protected  print protected branches, one per line
#     --explain    human-readable resolution + the evidence behind it
#     --json       {"base_branch":…,"protected_branches":[…],"source":…}
#     --no-cache   resolve without reading OR writing the cache
#     --refresh    ignore the cached value, re-resolve, rewrite the cache
#     --dir DIR    operate on DIR instead of the current directory
#
# Exit codes: 0 always when a repo is present (the fallback chain cannot fail).
#             1 only if DIR is not inside a git repository.
#
# Pure bash + git + optional gh/python3. No new dependency.

set -uo pipefail

PR_SAMPLE=30          # merged PRs to sample for the modal base ref
GH_TIMEOUT=10         # per-gh-call wall clock, so a hung network can't stall a branch creation

MODE="base"
USE_CACHE=1
REFRESH=0
DIR="$(pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --base)      MODE="base" ;;
    --protected) MODE="protected" ;;
    --explain)   MODE="explain" ;;
    --json)      MODE="json" ;;
    --no-cache)  USE_CACHE=0 ;;
    --refresh)   REFRESH=1 ;;
    --dir)       DIR="${2:-}"; shift ;;
    -h|--help)   sed -n '2,40p' "$0"; exit 0 ;;
    *)           echo "resolve-base-branch.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

# ─── Locate the repo ───
GIT_ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$GIT_ROOT" ]; then
  echo "resolve-base-branch.sh: '$DIR' is not inside a git repository" >&2
  exit 1
fi
CONFIG_FILE="$GIT_ROOT/.claude/project-config.json"

# ─── Helpers ───

# Read a key out of project-config.json. Absent file / bad JSON / missing key
# all yield empty rather than an error — this must never break a branch create.
_config_get() {
  local key="$1"
  [ -f "$CONFIG_FILE" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$CONFIG_FILE" "$key" <<'PY' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)
val = data.get(sys.argv[2])
if isinstance(val, list):
    print("\n".join(str(v) for v in val))
elif val is not None:
    print(val)
PY
}

# Run gh with a portable watchdog. macOS has no timeout(1) (same constraint
# foreign-review.sh works around), so background + poll + kill.
_gh() {
  command -v gh >/dev/null 2>&1 || return 1
  local out rc pid waited=0
  out=$(mktemp)
  ( cd "$GIT_ROOT" && gh "$@" >"$out" 2>/dev/null ) &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    [ "$waited" -ge "$GH_TIMEOUT" ] && { kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null; break; }
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" 2>/dev/null
  rc=$?
  cat "$out"
  rm -f "$out"
  return $rc
}

# Does a branch exist, locally or on the remote?
_branch_exists() {
  local b="$1"
  git -C "$GIT_ROOT" show-ref --verify --quiet "refs/heads/$b" && return 0
  git -C "$GIT_ROOT" show-ref --verify --quiet "refs/remotes/origin/$b" && return 0
  return 1
}

# ─── Resolution ───

BASE=""
PROTECTED=""
SOURCE=""
EVIDENCE=""

# 1. Explicit config wins, always.
if [ "$USE_CACHE" -eq 1 ] && [ "$REFRESH" -eq 0 ]; then
  CFG_BASE=$(_config_get base_branch)
  if [ -n "$CFG_BASE" ]; then
    BASE="$CFG_BASE"
    PROTECTED=$(_config_get protected_branches)
    [ -z "$PROTECTED" ] && PROTECTED="$BASE"
    SOURCE="config"
    EVIDENCE="base_branch set in .claude/project-config.json"
  fi
fi

# 2. Empirical: what do merged PRs actually target?
if [ -z "$BASE" ]; then
  PR_REFS=$(_gh pr list --state merged --limit "$PR_SAMPLE" --json baseRefName --jq '.[].baseRefName' || true)
  if [ -n "$PR_REFS" ]; then
    # Modal base ref = the branch feature work actually merges into.
    BASE=$(printf '%s\n' "$PR_REFS" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    TOTAL=$(printf '%s\n' "$PR_REFS" | wc -l | tr -d ' ')
    COUNT=$(printf '%s\n' "$PR_REFS" | grep -cx "$BASE" || true)

    # A branch is protected if it's a REAL integration target, not merely the
    # target of one stacked PR. Without a threshold, a single feature-onto-
    # feature PR would mark that feature branch protected and block work on it.
    # Gitflow's `main` clears this easily (7/20 in moveris-verification-ui);
    # a one-off stacked PR does not (1/29 in claude-workflow).
    PROTECTED=$(printf '%s\n' "$PR_REFS" | sort | uniq -c | sort -rn \
      | awk -v total="$TOTAL" '$1 >= 3 && ($1 * 100 / total) >= 10 { print $2 }')

    # The declared default branch is protected by definition, however few PRs
    # it happens to have received in the sample window.
    DEFAULT=$(_gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' || true)
    [ -n "$DEFAULT" ] && PROTECTED=$(printf '%s\n%s\n' "$PROTECTED" "$DEFAULT" | sed '/^$/d' | sort -u)

    SOURCE="merged-prs"
    EVIDENCE="$COUNT/$TOTAL recent merged PRs targeted '$BASE'"
  fi
fi

# 3. No PR history — fall back to the repo's declared default branch.
if [ -z "$BASE" ]; then
  DEFAULT=$(_gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' || true)
  if [ -n "$DEFAULT" ]; then
    BASE="$DEFAULT"
    PROTECTED="$DEFAULT"
    SOURCE="default-branch"
    EVIDENCE="no merged PR history; GitHub default branch is '$DEFAULT'"
  fi
fi

# 4. No gh / offline / not a GitHub remote — believe the refs on disk.
if [ -z "$BASE" ]; then
  for candidate in main master develop; do
    if _branch_exists "$candidate"; then
      BASE="$candidate"
      PROTECTED="$candidate"
      SOURCE="local-refs"
      EVIDENCE="gh unavailable; '$candidate' exists locally"
      break
    fi
  done
fi

# Last resort: the repo may have no commits yet.
if [ -z "$BASE" ]; then
  BASE=$(git -C "$GIT_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo main)
  PROTECTED="$BASE"
  SOURCE="head"
  EVIDENCE="no branches resolvable; using current HEAD '$BASE'"
fi

# Protected must always contain the base, even if a PR sample somehow missed it.
printf '%s\n' "$PROTECTED" | grep -qx "$BASE" || PROTECTED=$(printf '%s\n%s\n' "$BASE" "$PROTECTED" | sed '/^$/d' | sort -u)

# ─── Cache ───
# Only cache a NETWORK-derived answer. A local-refs/head guess is too weak to
# freeze — re-resolving later once gh is available should be able to correct it.
if [ "$USE_CACHE" -eq 1 ] && [ "$SOURCE" != "config" ]; then
  case "$SOURCE" in
    merged-prs|default-branch)
      if command -v python3 >/dev/null 2>&1; then
        mkdir -p "$GIT_ROOT/.claude"
        python3 - "$CONFIG_FILE" "$BASE" "$PROTECTED" <<'PY' 2>/dev/null || true
import json, sys, os
path, base, protected = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path) as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}
data["base_branch"] = base
data["protected_branches"] = [b for b in protected.split("\n") if b]
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PY
      fi
      ;;
  esac
fi

# ─── Output ───
case "$MODE" in
  base)      printf '%s\n' "$BASE" ;;
  protected) printf '%s\n' "$PROTECTED" ;;
  json)
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$BASE" "$PROTECTED" "$SOURCE" <<'PY'
import json, sys
print(json.dumps({
    "base_branch": sys.argv[1],
    "protected_branches": [b for b in sys.argv[2].split("\n") if b],
    "source": sys.argv[3],
}))
PY
    else
      printf '{"base_branch":"%s","source":"%s"}\n' "$BASE" "$SOURCE"
    fi
    ;;
  explain)
    echo "Base branch:  $BASE"
    echo "Protected:    $(printf '%s' "$PROTECTED" | tr '\n' ' ')"
    echo "Resolved via: $SOURCE"
    echo "Evidence:     $EVIDENCE"
    ;;
esac

exit 0
