#!/usr/bin/env bash
set -uo pipefail

# Regression tests for drift-check.sh precision after the Phase 3 retarget.
# Locks in: a clean 3-file Memory Bank scores healthy; CLAUDE.md /
# ~/.claude/rules references and version/abbreviation prose do NOT tank the
# score (the reverted CLAUDE.md-scan bug); ~/.claude/ paths in task-context
# are not misread as branches; real dead paths ARE still caught.
# Plus the 2026-07-10 check_paths precision rework (moveris_cluster scored
# 0/100 on 272 false positives): prose tokens (domains, emails, CLI flags,
# systemd units, dotted identifiers, sizes, product names) are not file refs;
# references resolve by basename/suffix against the repo tree, against sibling
# repo checkouts, and against the repo's own docs; retired pre-v3 memory files
# (activeContext/progress/sessionHistory) are skipped entirely.
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

# --- Prose tokens are not file references ---
PROSE="$TMP/prose-project"
mkdir -p "$PROSE/.claude/memory"
cat > "$PROSE/.claude/memory/conventions.md" <<'EOF'
# Conventions & Lessons
### Ops prose that must not read as file refs
Email justin.r.keene@gmail.com or ops@moveris.com; DNS stays tail7dafd3.ts.net.
Run node_exporter with --collector.systemd and --collector.textfile.directory.
Mount options: x-systemd.automount, x-systemd.mount; units: suspend.target,
hibernate.target, enp0s1.network. Celery task `moveris.generate.api` calls
`cv2.VideoCapture` and `sqlite3.Row`. Sizes: 1.9T used, 1.22M rows, 129K/13.5K.
Stack: Next.js on Fly.io. Runtime artifacts: backup.log, generation_manifest.db.
EOF
PSCORE=$(score_of "$PROSE")
PERR=$( cd "$PROSE" && bash "$DRIFT" 2>/dev/null | grep -c 'file not found' || true )
if [ "$PERR" -eq 0 ] && [ "$PSCORE" -eq 100 ]; then
  ok "prose tokens (domains/flags/units/identifiers/sizes/products) not flagged"
else
  echo "  --- findings ---"; ( cd "$PROSE" && bash "$DRIFT" 2>/dev/null | grep 'file not found' | head )
  bad "prose project scored $PSCORE with $PERR false dead-path error(s)"
fi

# --- References resolve by basename/suffix against the repo tree ---
SUBDIR="$TMP/subdir-project"
mkdir -p "$SUBDIR/.claude/memory" "$SUBDIR/docs" "$SUBDIR/scripts" "$SUBDIR/data-platform/checks"
echo x > "$SUBDIR/docs/storage.md"
echo x > "$SUBDIR/scripts/deploy-monitoring.sh"
echo x > "$SUBDIR/data-platform/checks/restore_test.sh"
cat > "$SUBDIR/.claude/memory/conventions.md" <<'EOF'
# Conventions
See storage.md for the NAS layout; redeploy with deploy-monitoring.sh.
Restore drills run checks/restore_test.sh nightly.
EOF
SSCORE=$(score_of "$SUBDIR")
if [ "$SSCORE" -eq 100 ]; then
  ok "bare-basename and partial-path refs resolve against the repo tree"
else
  echo "  --- findings ---"; ( cd "$SUBDIR" && bash "$DRIFT" 2>/dev/null | grep 'file not found' | head )
  bad "subdir-resolution project scored $SSCORE (expected 100)"
fi

# --- Cross-repo references resolve against sibling checkouts ---
SIBPARENT="$TMP/siblings"
mkdir -p "$SIBPARENT/app/.claude/memory" "$SIBPARENT/other/src/lib"
echo x > "$SIBPARENT/other/src/lib/changelog.ts"
git -C "$SIBPARENT/other" init -q 2>/dev/null || true
git -C "$SIBPARENT/other" add src/lib/changelog.ts 2>/dev/null || true
cat > "$SIBPARENT/app/.claude/memory/conventions.md" <<'EOF'
# Conventions
Mira deploys announce from the TOP entry of src/lib/changelog.ts.
EOF
XSCORE=$(score_of "$SIBPARENT/app")
if [ "$XSCORE" -eq 100 ]; then
  ok "cross-repo refs resolve against sibling repo checkouts"
else
  echo "  --- findings ---"; ( cd "$SIBPARENT/app" && bash "$DRIFT" 2>/dev/null | grep 'file not found' | head )
  bad "sibling-resolution project scored $XSCORE (expected 100)"
fi

# --- Off-machine artifacts named in the repo's own docs are not drift ---
DOCREF="$TMP/docref-project"
mkdir -p "$DOCREF/.claude/memory" "$DOCREF/docs"
echo "Nodes rebuild the venv with scripts/setup_node_env.sh on first boot." > "$DOCREF/docs/ops.md"
cat > "$DOCREF/.claude/memory/conventions.md" <<'EOF'
# Conventions
The env-bootstrap convention: scripts/setup_node_env.sh recreates the venv.
EOF
DOCSCORE=$(score_of "$DOCREF")
if [ "$DOCSCORE" -eq 100 ]; then
  ok "artifacts named in the repo's own docs not flagged as dead paths"
else
  echo "  --- findings ---"; ( cd "$DOCREF" && bash "$DRIFT" 2>/dev/null | grep 'file not found' | head )
  bad "doc-corpus project scored $DOCSCORE (expected 100)"
fi

# --- Retired pre-v3 files are skipped entirely ---
RETIRED="$TMP/retired-project"
mkdir -p "$RETIRED/.claude/memory"
cat > "$RETIRED/.claude/memory/activeContext.md" <<'EOF'
# Active Context (pre-v3, pending /memory-migrate)
Historical log naming src/long-gone.ts and scripts/removed-tool.sh repeatedly.
Also scripts/removed-tool.sh again, and src/long-gone.ts once more.
EOF
cp "$RETIRED/.claude/memory/activeContext.md" "$RETIRED/.claude/memory/progress.md"
cp "$RETIRED/.claude/memory/activeContext.md" "$RETIRED/.claude/memory/sessionHistory.md"
cat > "$RETIRED/.claude/memory/conventions.md" <<'EOF'
# Conventions
Nothing stale here.
EOF
RSCORE=$(score_of "$RETIRED")
if [ "$RSCORE" -eq 100 ]; then
  ok "retired pre-v3 files (activeContext/progress/sessionHistory) skipped"
else
  echo "  --- findings ---"; ( cd "$RETIRED" && bash "$DRIFT" 2>/dev/null | grep -E 'ERROR|WARN' | head )
  bad "retired-files project scored $RSCORE (expected 100)"
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
