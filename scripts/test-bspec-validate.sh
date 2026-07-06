#!/usr/bin/env bash
# test-bspec-validate.sh — regression tests for scripts/bspec-validate.sh
# The released BSpec CLI does not validate (it archives garbage clean), so this
# script IS the enforcement layer — guard it. Pure bash 3.2, no deps beyond python3.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$SCRIPT_DIR/bspec-validate.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

N=0
newdir() { N=$((N + 1)); D="$TMP/c$N"; mkdir -p "$D"; }

# Writes a doc; call: doc <file> then heredoc via stdin is awkward, so use a helper.
valid_doc() { # dir  code  id
  cat > "$1/$2-x-v1.0.0.md" <<EOF
---
id: $3
title: Test $2
type: $2
status: Draft
version: 1.0.0
owner: Team
domain: product
created: 2026-07-06
updated: 2026-07-06
---
# body
EOF
}

# 1. A conformant doc passes (exit 0, OK line).
newdir; valid_doc "$D" PRD prd-x-001
OUT="$(bash "$VALIDATE" "$D/PRD-x-v1.0.0.md" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && echo "$OUT" | grep -q '^OK:'; } \
  && ok "conformant doc passes (exit 0)" || no "conformant doc passes (rc=$RC)"

# 2. Unknown type code is rejected (the CLI accepts this; we must not).
newdir
cat > "$D/ZZZ-bad-v1.0.0.md" <<'EOF'
---
id: zzz-bad-001
title: Bad
type: NOTATYPE
status: Draft
version: 1.0.0
owner: t
domain: d
created: 2026-07-06
updated: 2026-07-06
---
x
EOF
OUT="$(bash "$VALIDATE" "$D/ZZZ-bad-v1.0.0.md" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'unknown type'; } \
  && ok "unknown type code rejected" || no "unknown type code rejected (rc=$RC)"

# 3. Missing a required field (title) fails.
newdir
cat > "$D/PRD-notitle-v1.0.0.md" <<'EOF'
---
id: prd-nt-001
type: PRD
status: Draft
version: 1.0.0
---
x
EOF
OUT="$(bash "$VALIDATE" "$D/PRD-notitle-v1.0.0.md" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'missing required field: title'; } \
  && ok "missing required field rejected" || no "missing required field rejected (rc=$RC)"

# 4. Invalid status value fails.
newdir
cat > "$D/PRD-badstatus-v1.0.0.md" <<'EOF'
---
id: prd-bs-001
title: X
type: PRD
status: Whatever
version: 1.0.0
owner: t
domain: d
created: 2026-07-06
updated: 2026-07-06
---
x
EOF
OUT="$(bash "$VALIDATE" "$D/PRD-badstatus-v1.0.0.md" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'invalid status'; } \
  && ok "invalid status rejected" || no "invalid status rejected (rc=$RC)"

# 5. Dangling relationship reference fails; 6. a resolved one passes.
newdir; valid_doc "$D" MSN msn-mission-001
cat > "$D/PRD-linked-v1.0.0.md" <<'EOF'
---
id: prd-linked-001
title: Linked
type: PRD
status: Draft
version: 1.0.0
owner: t
domain: product
created: 2026-07-06
updated: 2026-07-06
depends_on: [msn-mission-001, ghost-999]
---
x
EOF
OUT="$(bash "$VALIDATE" "$D/PRD-linked-v1.0.0.md" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "unknown id 'ghost-999'"; } \
  && ok "dangling relationship rejected" || no "dangling relationship rejected (rc=$RC)"
# resolved-only link passes
cat > "$D/PRD-ok-v1.0.0.md" <<'EOF'
---
id: prd-ok-001
title: OK
type: PRD
status: Draft
version: 1.0.0
owner: t
domain: product
created: 2026-07-06
updated: 2026-07-06
related: [msn-mission-001]
---
x
EOF
OUT="$(bash "$VALIDATE" "$D/PRD-ok-v1.0.0.md" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "resolved relationship passes" || no "resolved relationship passes (rc=$RC)"

# 7. A file named directly with no frontmatter fails.
newdir
printf 'no frontmatter here\n' > "$D/PRD-nofm-v1.0.0.md"
OUT="$(bash "$VALIDATE" "$D/PRD-nofm-v1.0.0.md" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'missing or malformed'; } \
  && ok "no-frontmatter file rejected" || no "no-frontmatter file rejected (rc=$RC)"

# 8. Directory scan: skips README, flags the garbage doc, exits 1.
newdir; valid_doc "$D" PRD prd-dir-001
printf '# just a readme\n' > "$D/README.md"
cat > "$D/FEA-broken-v1.0.0.md" <<'EOF'
---
id: fea-broken-001
type: NOTATYPE
status: Draft
---
x
EOF
OUT="$(bash "$VALIDATE" "$D" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && ! echo "$OUT" | grep -q 'README.md'; } \
  && ok "dir scan flags garbage, skips README" || no "dir scan flags garbage, skips README (rc=$RC)"

# 9. --quiet suppresses OK lines for a clean doc.
newdir; valid_doc "$D" API api-x-001
OUT="$(bash "$VALIDATE" --quiet "$D/API-x-v1.0.0.md" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q '^OK:'; } \
  && ok "--quiet hides OK lines" || no "--quiet hides OK lines (rc=$RC)"

echo
echo "Passed: $PASS  Failed: $FAIL"
if [ "$FAIL" -eq 0 ]; then echo "All bspec-validate tests passed."; else echo "Some bspec-validate tests failed."; fi
[ "$FAIL" -eq 0 ]
