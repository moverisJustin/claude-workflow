#!/usr/bin/env bash
# test-resolve-base-branch.sh — guard tests for the branch-model resolver.
#
# Pure bash, no network. `gh` is stubbed via a fixture PATH so every branching
# model can be exercised deterministically: real repos change, fixtures don't.
# The real-repo assertions (moveris_training_data=master, mira=main,
# moveris-verification-ui=develop) are documented in the task charter and were
# verified by hand; they are deliberately NOT in here, because a unit test that
# needs the network and a specific org is a test that rots.
#
# Run: bash scripts/test-resolve-base-branch.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$SCRIPT_DIR/resolve-base-branch.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "  ok   — $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL — $1"; echo "         expected: $2"; echo "         actual:   $3"; }
check(){ [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

# Build a fake repo whose `gh` returns the given merged-PR base refs and
# default branch. Empty PR_REFS exercises the no-history path; STUB=none
# exercises the no-gh path.
make_repo() {
  local name="$1" pr_refs="$2" default="$3" stub="${4:-gh}"
  local d="$WORK/$name"
  mkdir -p "$d/bin"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t
  git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty --no-gpg-sign -m init

  if [ "$stub" = "gh" ]; then
    cat >"$d/bin/gh" <<STUB
#!/usr/bin/env bash
# Minimal gh stub: only the two calls the resolver makes.
case "\$*" in
  *"pr list"*)     printf '%s' '$pr_refs' ;;
  *"repo view"*)   printf '%s\n' '$default' ;;
esac
exit 0
STUB
    chmod +x "$d/bin/gh"
  fi
  echo "$d"
}

# Run the resolver against a fixture with only the fixture's bin on PATH,
# so a real `gh` on the developer's machine can never leak into a test.
run() {
  local dir="$1"; shift
  PATH="$dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" bash "$RESOLVER" --dir "$dir" "$@"
}

echo "test-resolve-base-branch"
echo

# ─── 1. main-only repo ───
D=$(make_repo main-only 'main
main
main
main
main' main)
check "main-only: base is main"        "main" "$(run "$D" --base --no-cache)"
check "main-only: only main protected" "main" "$(run "$D" --protected --no-cache)"

# ─── 2. master-only repo (the moveris_training_data shape) ───
D=$(make_repo master-only 'master
master
master
master
master' master)
check "master-only: base is master"        "master" "$(run "$D" --base --no-cache)"
check "master-only: only master protected" "master" "$(run "$D" --protected --no-cache)"

# ─── 3. gitflow: features → develop, releases → main. BOTH protected. ───
D=$(make_repo gitflow 'develop
develop
develop
develop
develop
develop
develop
develop
develop
develop
develop
develop
develop
main
main
main
main
main
main
main' main)
check "gitflow: base is develop" "develop" "$(run "$D" --base --no-cache)"
check "gitflow: develop AND main protected" \
  "$(printf 'develop\nmain')" "$(run "$D" --protected --no-cache)"

# ─── 4. A single stacked PR must NOT make a feature branch protected ───
# Regression guard: without the >=3 AND >=10% threshold, one feature-onto-
# feature PR marked that branch protected, which would block work on it.
D=$(make_repo stacked 'main
main
main
main
main
main
main
main
main
main
main
main
main
main
main
main
main
main
main
feature/stacked' main)
check "stacked: base is main"                 "main" "$(run "$D" --base --no-cache)"
check "stacked: feature branch NOT protected" "main" "$(run "$D" --protected --no-cache)"

# ─── 5. No PR history → fall back to the declared default branch ───
D=$(make_repo no-prs '' develop)
check "no-prs: base from default branch" "develop" "$(run "$D" --base --no-cache)"
check "no-prs: source is default-branch" "default-branch" \
  "$(run "$D" --json --no-cache | sed 's/.*"source": *"\([^"]*\)".*/\1/')"

# ─── 6. No gh at all → believe the refs on disk ───
D=$(make_repo no-gh '' '' none)
git -C "$D" branch -M master
check "no-gh: falls back to local refs" "master" "$(run "$D" --base --no-cache)"

# ─── 7. Explicit config beats everything ───
D=$(make_repo config-wins 'main
main
main
main
main' main)
mkdir -p "$D/.claude"
cat >"$D/.claude/project-config.json" <<'JSON'
{"base_branch": "develop", "protected_branches": ["develop", "main"]}
JSON
check "config: overrides the empirical answer" "develop" "$(run "$D" --base)"
check "config: protected read from config" \
  "$(printf 'develop\nmain')" "$(run "$D" --protected)"
check "config: --refresh ignores the cache" "main" "$(run "$D" --base --refresh --no-cache)"

# ─── 8. Caching: resolve once, persist, and don't re-hit the network ───
D=$(make_repo caching 'master
master
master
master
master' master)
run "$D" --base >/dev/null
check "cache: base_branch written to project-config.json" "master" \
  "$(python3 -c 'import json;print(json.load(open("'"$D"'/.claude/project-config.json"))["base_branch"])' 2>/dev/null)"
# With gh removed, the cached value must still resolve.
rm -f "$D/bin/gh"
check "cache: survives gh disappearing" "master" "$(run "$D" --base)"

# ─── 9. Caching must NOT freeze a weak (local-refs) guess ───
# A guess made while offline should be correctable once gh is available.
D=$(make_repo weak-guess '' '' none)
git -C "$D" branch -M main
run "$D" --base >/dev/null
check "cache: local-refs guess is NOT cached" "" \
  "$(python3 -c 'import json;print(json.load(open("'"$D"'/.claude/project-config.json")).get("base_branch",""))' 2>/dev/null || echo "")"

# ─── 10. Caching preserves unrelated project-config keys ───
D=$(make_repo preserve 'main
main
main
main
main' main)
mkdir -p "$D/.claude"
echo '{"git_enabled": false}' >"$D/.claude/project-config.json"
run "$D" --base >/dev/null
check "cache: unrelated keys preserved" "False" \
  "$(python3 -c 'import json;print(json.load(open("'"$D"'/.claude/project-config.json"))["git_enabled"])' 2>/dev/null)"

# ─── 11. Not a git repo → exit 1, loudly ───
mkdir -p "$WORK/plain"
if bash "$RESOLVER" --dir "$WORK/plain" --base >/dev/null 2>&1; then
  bad "non-git dir exits 1" "exit 1" "exit 0"
else
  ok "non-git dir exits 1"
fi

# ─── 12. Protected always contains the base ───
D=$(make_repo invariant 'develop
develop
develop
develop
develop' main)
if run "$D" --protected --no-cache | grep -qx develop; then
  ok "invariant: protected always contains the base"
else
  bad "invariant: protected always contains the base" "develop present" "$(run "$D" --protected --no-cache)"
fi

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
