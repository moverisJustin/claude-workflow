#!/usr/bin/env bash
set -uo pipefail

# Regression tests for maintenance-check.sh doc-count self-audit.
# Builds a tiny fixture repo with known counts and matching docs (expect
# clean / exit 0), then breaks a doc count (expect drift / exit 1).
# Pure bash 3.2. Exits non-zero on any failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "=== test-maintenance.sh ==="

# --- Fixture repo: 2 core agents, 3 vendored community (2 active), 2 skills, 1 hook ---
F="$TMP/repo"
mkdir -p "$F/scripts" "$F/agents/community" "$F/skills/alpha" "$F/skills/beta"
cp "$SCRIPT_DIR/maintenance-check.sh" "$F/scripts/"
cp "$SCRIPT_DIR/drift-check.sh" "$F/scripts/" 2>/dev/null || true
printf '%s\n' '---' 'name: a' '---' > "$F/agents/a.md"
printf '%s\n' '---' 'name: b' '---' > "$F/agents/b.md"
for c in engineering-x engineering-y sales-z; do printf '%s\n' '---' "name: $c" '---' > "$F/agents/community/$c.md"; done
cat > "$F/agents/community/MANIFEST.txt" <<'EOF'
# active
engineering-x
engineering-y
# opt-in
# sales-z
EOF
printf '# alpha\n' > "$F/skills/alpha/SKILL.md"
printf '# beta\n'  > "$F/skills/beta/SKILL.md"
printf '#!/bin/bash\n' > "$F/scripts/hook-demo.sh"

write_readme() { # core skills hooks active vendored
cat > "$F/README.md" <<EOF
# Fixture
| Category | Count | Highlights |
|---|---|---|
| Core agents | $1 | ... |
| Community agents | $4 active / $5 vendored | ... |
| Skills | $2 | ... |
| Hook scripts | $3 | ... |
EOF
}
cat > "$F/CHEATSHEET.md" <<'EOF'
## Core Agents (2)
EOF

# --- Matching docs -> clean, exit 0 ---
write_readme 2 2 1 2 3
if /bin/bash "$F/scripts/maintenance-check.sh" >/dev/null 2>&1; then ok "matching doc counts -> clean (exit 0)"; else bad "matching counts flagged drift"; fi
OUT=$(/bin/bash "$F/scripts/maintenance-check.sh" 2>&1)
if echo "$OUT" | grep -q 'OK    community active: 2'; then ok "community active count parsed from '2 active / 3 vendored'"; else bad "community active parse wrong"; fi
if echo "$OUT" | grep -q 'OK    community vendored: 3'; then ok "community vendored count parsed"; else bad "community vendored parse wrong"; fi

# --- Wrong core count -> drift, exit 1 ---
write_readme 9 2 1 2 3
if /bin/bash "$F/scripts/maintenance-check.sh" >/dev/null 2>&1; then bad "stale core count (9 vs 2) NOT detected"; else ok "stale core count detected (exit 1)"; fi
OUT=$(/bin/bash "$F/scripts/maintenance-check.sh" 2>&1)
if echo "$OUT" | grep -q 'DRIFT core agents: actual 2 but README says 9'; then ok "drift report names the mismatch"; else bad "drift report unclear"; fi

# --- Wrong skills count -> drift ---
write_readme 2 5 1 2 3
if /bin/bash "$F/scripts/maintenance-check.sh" >/dev/null 2>&1; then bad "stale skills count NOT detected"; else ok "stale skills count detected"; fi

# --- quiet mode output shape ---
write_readme 2 2 1 2 3
if /bin/bash "$F/scripts/maintenance-check.sh" --quiet 2>&1 | grep -q 'maintenance: clean'; then ok "quiet mode reports clean"; else bad "quiet mode output wrong"; fi

echo ""
echo "Passed: $pass  Failed: $fail"
[ "$fail" -ne 0 ] && exit 1
echo "All maintenance-check tests passed."
