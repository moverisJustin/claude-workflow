#!/usr/bin/env bash
set -uo pipefail

# Regression tests for drift-check.sh precision after the Phase 3 retarget.
# Locks in: a clean 3-file Memory Bank scores healthy; CLAUDE.md /
# ~/.claude/rules references and version/abbreviation prose do NOT tank the
# score (the reverted CLAUDE.md-scan bug); ~/.claude/ paths in task-context
# are not misread as branches; real dead paths ARE still caught.
# Pure bash 3.2. Exits non-zero on any failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIFT="$SCRIPT_DIR/drift-check.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

score_of() { # runs drift-check in $1, echoes numeric score
  ( cd "$1" && bash "$DRIFT" --quiet 2>/dev/null ) | grep -oE 'Score: [0-9]+' | grep -oE '[0-9]+'
}

echo "=== test-drift-check.sh ==="

# --- Fixture: a clean, freshly-initialized Boris v3 project ---
PROJ="$TMP/clean-project"
mkdir -p "$PROJ/.claude/memory" "$PROJ/rules"
git -C "$PROJ" init -q 2>/dev/null || true
git -C "$PROJ" -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
  commit --allow-empty -qm init 2>/dev/null || true
# task-context.md lives on its own branch — create it so the branch checker
# finds it (models reality; a missing branch SHOULD warn, tested separately)
git -C "$PROJ" checkout -q -b feature/sample-work 2>/dev/null || true

# The slim v3 CLAUDE.md references files by bare basename + ~/.claude paths.
cat > "$PROJ/CLAUDE.md" <<'EOF'
# Quick Reference (Boris v3)

Rules live in `~/.claude/rules/`: `git-safety.md`, `workflow.md`, `learned-patterns.md`.
Memory: `projectContext.md`, `decisionLog.md`, `conventions.md`. Native: `MEMORY.md`.
See Boris v2.0 history. Contact team, e.g. via example.com.
EOF

cat > "$PROJ/.claude/memory/projectContext.md" <<'EOF'
# Project Context
## Identity
A sample project. Stack: Node.js. See README.md for setup.
EOF
echo "README" > "$PROJ/README.md"

cat > "$PROJ/.claude/memory/decisionLog.md" <<'EOF'
# Decision Log
## 2026-01-01 - Use the Memory Bank
Accepted. Rationale: structured knowledge, e.g. ADRs.
EOF

cat > "$PROJ/.claude/memory/conventions.md" <<'EOF'
# Conventions & Lessons
### Prefer 2-space indent
Applies to Boris v3.0 code. See package.json scripts.
EOF
echo '{}' > "$PROJ/package.json"

# task-context.md full of ~/.claude/ paths (the branch-regex trap)
cat > "$PROJ/.claude/task-context.md" <<'EOF'
# Task Context — feature/sample-work
## Notes
Rules at ~/.claude/rules/, plans at ~/.claude/plans/, context at ~/.claude/context/.
EOF

SCORE=$(score_of "$PROJ")
if [ "$SCORE" -ge 80 ]; then
  ok "clean v3 project scores healthy ($SCORE/100)"
else
  echo "  --- findings ---"; ( cd "$PROJ" && bash "$DRIFT" 2>/dev/null | grep -E 'ERROR|WARN' | head )
  bad "clean v3 project scored $SCORE (< 80) — false positives regressed"
fi

# No branch warnings from ~/.claude/ path segments
BRANCHWARN=$( cd "$PROJ" && bash "$DRIFT" 2>/dev/null | grep -c 'branch not found' || true )
if [ "$BRANCHWARN" -eq 0 ]; then ok "no ~/.claude/ path misread as a branch"; else bad "$BRANCHWARN false branch warning(s)"; fi

# CLAUDE.md bare-basename refs did not fire dead-path errors
CLAUDEERR=$( cd "$PROJ" && bash "$DRIFT" 2>/dev/null | grep -cE 'references (git-safety|workflow|learned-patterns|MEMORY|projectContext|decisionLog|conventions)\.md' || true )
if [ "$CLAUDEERR" -eq 0 ]; then ok "CLAUDE.md/native basenames not flagged as dead paths"; else bad "$CLAUDEERR false dead-path error(s) from doc basenames"; fi

# --- Real drift IS still caught ---
DIRTY="$TMP/dirty-project"
mkdir -p "$DIRTY/.claude/memory"
cat > "$DIRTY/.claude/memory/projectContext.md" <<'EOF'
# Project Context
The entry point is src/does-not-exist.ts and config in build/missing-config.json.
EOF
DSCORE=$(score_of "$DIRTY")
DERR=$( cd "$DIRTY" && bash "$DRIFT" 2>/dev/null | grep -c 'file not found' || true )
if [ "$DERR" -ge 2 ] && [ "$DSCORE" -lt 100 ]; then
  ok "genuine dead paths still detected (score $DSCORE, $DERR errors)"
else
  bad "real dead paths NOT detected (score $DSCORE, $DERR errors) — checker too lax now"
fi

# --- No Memory Bank → silent skip (what CI's fresh checkout sees) ---
EMPTY="$TMP/no-memory"
mkdir -p "$EMPTY"
if ( cd "$EMPTY" && bash "$DRIFT" --quiet 2>/dev/null | grep -q 'No Memory Bank' ); then
  ok "no Memory Bank: skips cleanly"
else
  bad "no Memory Bank: did not skip"
fi

echo ""
echo "Passed: $pass  Failed: $fail"
[ "$fail" -ne 0 ] && exit 1
echo "All drift-check regression tests passed."
