#!/usr/bin/env bash
# test-validate-findings.sh — guard tests for validate-findings.mjs.
#
# One test per restricted-dialect keyword (type object/array/string/integer,
# required, properties, enum, maxItems, maxLength, additionalProperties:false,
# items), plus missing-required / wrong-type / extra-property / nested-object
# error paths, unparsable inputs, the closed-dialect (unknown keyword) guard,
# and a fully valid document.
#
# Self-contained offline: fixtures are written inline to a mktemp dir. No
# network, no AI. Run after any change to validate-findings.mjs.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUT="$SCRIPT_DIR/validate-findings.mjs"
NODE_BIN="${NODE_BIN:-node}"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

assert_eq() { # <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (want '$2' got '$3')"; fi
}
assert_contains() { # <desc> <haystack> <needle>
  case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (missing: $3)" ;; esac
}

DIR="$(mktemp -d "${TMPDIR:-/tmp}/vf-test.XXXXXX")"
trap 'rm -rf "$DIR"' EXIT

SCHEMA="$DIR/schema.json"
DOC="$DIR/doc.json"

# Fixture schema exercising every dialect keyword.
cat > "$SCHEMA" <<'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "test findings",
  "type": "object",
  "additionalProperties": false,
  "required": ["verdict", "findings"],
  "properties": {
    "verdict": { "type": "string", "enum": ["approve", "revise"] },
    "count": { "type": "integer" },
    "findings": {
      "type": "array",
      "maxItems": 3,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["title"],
        "properties": {
          "title": { "type": "string", "maxLength": 20 },
          "severity": { "type": "string", "enum": ["low", "high"] }
        }
      }
    }
  }
}
EOF

run() { # <doc-json> -> sets RC and ERR
  printf '%s' "$1" > "$DOC"
  ERR="$("$NODE_BIN" "$SUT" "$SCHEMA" "$DOC" 2>&1)"
  RC=$?
}

# --- 1. valid document ------------------------------------------------------
echo "valid document"
run '{"verdict":"approve","count":2,"findings":[{"title":"ok","severity":"low"},{"title":"also ok"}]}'
assert_eq "valid doc exits 0"            0 "$RC"
assert_eq "valid doc prints nothing"     "" "$ERR"

run '{"verdict":"revise","findings":[]}'
assert_eq "optional props omittable"     0 "$RC"

# --- 2. required ------------------------------------------------------------
echo "required"
run '{"findings":[]}'
assert_eq       "missing required exits 1"    1 "$RC"
assert_contains "names the missing property"  "$ERR" "missing required property 'verdict'"

# --- 3. type keyword, each type ---------------------------------------------
echo "type checks"
run '{"verdict":3,"findings":[]}'
assert_eq       "wrong type (string) exits 1" 1 "$RC"
assert_contains "string error names path"     "$ERR" '$.verdict'
assert_contains "string error says expected"  "$ERR" "expected string"

run '{"verdict":"approve","count":"x","findings":[]}'
assert_eq       "wrong type (integer) exits 1" 1 "$RC"
assert_contains "integer error names count"    "$ERR" '$.count'

run '{"verdict":"approve","count":1.5,"findings":[]}'
assert_eq       "non-integer number exits 1"   1 "$RC"
assert_contains "float rejected as integer"    "$ERR" "expected integer"

run '{"verdict":"approve","findings":{}}'
assert_eq       "wrong type (array) exits 1"   1 "$RC"
assert_contains "array error says expected"    "$ERR" "expected array"

run '[]'
assert_eq       "wrong type (object root) exits 1" 1 "$RC"
assert_contains "root error at \$"             "$ERR" "expected object"

# --- 4. enum ----------------------------------------------------------------
echo "enum"
run '{"verdict":"maybe","findings":[]}'
assert_eq       "enum violation exits 1"      1 "$RC"
assert_contains "enum error names value"      "$ERR" '"maybe"'
assert_contains "enum error says enum"        "$ERR" "not one of enum"

# --- 5. maxItems ------------------------------------------------------------
echo "maxItems"
run '{"verdict":"approve","findings":[{"title":"a"},{"title":"b"},{"title":"c"},{"title":"d"}]}'
assert_eq       "maxItems violation exits 1"  1 "$RC"
assert_contains "maxItems error is specific"  "$ERR" "exceeds maxItems 3"

# --- 6. maxLength -----------------------------------------------------------
echo "maxLength"
run '{"verdict":"approve","findings":[{"title":"this title is much too long for the cap"}]}'
assert_eq       "maxLength violation exits 1" 1 "$RC"
assert_contains "maxLength error is specific" "$ERR" "exceeds maxLength 20"

# --- 7. additionalProperties:false ------------------------------------------
echo "additionalProperties"
run '{"verdict":"approve","findings":[],"sneaky":true}'
assert_eq       "extra property exits 1"      1 "$RC"
assert_contains "extra property is named"     "$ERR" "unexpected additional property 'sneaky'"

# --- 8. nested-object errors (items + path reporting) ------------------------
echo "nested objects"
run '{"verdict":"approve","findings":[{"title":"ok"},{"severity":"low"}]}'
assert_eq       "nested missing required exits 1" 1 "$RC"
assert_contains "nested path is indexed"          "$ERR" '$.findings[1]'
assert_contains "nested missing prop named"       "$ERR" "missing required property 'title'"

run '{"verdict":"approve","findings":[{"title":"ok","severity":"medium"}]}'
assert_eq       "nested enum violation exits 1"   1 "$RC"
assert_contains "nested enum path"                "$ERR" '$.findings[0].severity'

run '{"verdict":"approve","findings":[{"title":"ok","extra":1}]}'
assert_eq       "nested extra property exits 1"   1 "$RC"
assert_contains "nested extra property named"     "$ERR" "unexpected additional property 'extra'"

# --- 9. multiple errors reported together ------------------------------------
echo "multiple errors"
run '{"verdict":"maybe","count":"x"}'
assert_contains "reports enum error"          "$ERR" "not one of enum"
assert_contains "reports type error"          "$ERR" '$.count'
assert_contains "reports missing findings"    "$ERR" "missing required property 'findings'"

# --- 10. unparsable inputs ---------------------------------------------------
echo "unparsable inputs"
printf 'not json' > "$DOC"
ERR="$("$NODE_BIN" "$SUT" "$SCHEMA" "$DOC" 2>&1)"; RC=$?
assert_eq       "broken doc JSON exits 1"     1 "$RC"
assert_contains "broken doc JSON reported"    "$ERR" "not valid JSON"

BADSCHEMA="$DIR/bad-schema.json"
printf '{ nope' > "$BADSCHEMA"
printf '{}' > "$DOC"
ERR="$("$NODE_BIN" "$SUT" "$BADSCHEMA" "$DOC" 2>&1)"; RC=$?
assert_eq       "broken schema JSON exits 1"  1 "$RC"
assert_contains "broken schema reported"      "$ERR" "not valid JSON"

ERR="$("$NODE_BIN" "$SUT" "$DIR/nonexistent.json" "$DOC" 2>&1)"; RC=$?
assert_eq       "missing schema file exits 1" 1 "$RC"
assert_contains "missing file reported"       "$ERR" "cannot read"

ERR="$("$NODE_BIN" "$SUT" "$SCHEMA" 2>&1)"; RC=$?
assert_eq       "usage error exits 1"         1 "$RC"
assert_contains "usage printed"               "$ERR" "usage:"

# --- 11. closed dialect: unknown schema keyword is rejected -------------------
echo "closed dialect"
UNKNOWN="$DIR/unknown-kw.json"
cat > "$UNKNOWN" <<'EOF'
{ "type": "object", "properties": { "x": { "type": "array", "minItems": 1 } } }
EOF
printf '{"x":[]}' > "$DOC"
ERR="$("$NODE_BIN" "$SUT" "$UNKNOWN" "$DOC" 2>&1)"; RC=$?
assert_eq       "unknown keyword exits 1"     1 "$RC"
assert_contains "unknown keyword named"       "$ERR" "unsupported schema keyword 'minItems'"
assert_contains "keyword path reported"       "$ERR" '$.properties.x'

BADTYPE="$DIR/bad-type.json"
printf '{ "type": "number" }' > "$BADTYPE"
printf '3.2' > "$DOC"
ERR="$("$NODE_BIN" "$SUT" "$BADTYPE" "$DOC" 2>&1)"; RC=$?
assert_eq       "unsupported type exits 1"    1 "$RC"
assert_contains "unsupported type named"      "$ERR" "unsupported type 'number'"

BADAP="$DIR/bad-ap.json"
printf '{ "type": "object", "additionalProperties": true }' > "$BADAP"
printf '{}' > "$DOC"
ERR="$("$NODE_BIN" "$SUT" "$BADAP" "$DOC" 2>&1)"; RC=$?
assert_eq       "additionalProperties:true rejected" 1 "$RC"
assert_contains "ap:true reason given"        "$ERR" "must be false"

# annotation keys are permitted (already covered implicitly by the main schema,
# which carries $schema + title and validates cleanly — asserted in section 1).

# --- prototype-chain hardening: Object.prototype names are not "present" -----
PROTO="$DIR/proto.json"
printf '{ "type": "object", "additionalProperties": false, "required": ["a"], "properties": { "a": { "type": "string" } } }' > "$PROTO"
printf '{ "a": "x", "toString": "sneaky" }' > "$DOC"
ERR="$("$NODE_BIN" "$SUT" "$PROTO" "$DOC" 2>&1)"; RC=$?
assert_eq       "toString extra prop exits 1"   1 "$RC"
assert_contains "toString extra prop named"     "$ERR" "unexpected additional property 'toString'"
printf '{ "a": "x", "constructor": "sneaky" }' > "$DOC"
"$NODE_BIN" "$SUT" "$PROTO" "$DOC" >/dev/null 2>&1
assert_eq       "constructor extra prop exits 1" 1 "$?"
REQPROTO="$DIR/req-proto.json"
printf '{ "type": "object", "required": ["toString"], "properties": { "toString": { "type": "string" } } }' > "$REQPROTO"
printf '{}' > "$DOC"
ERR="$("$NODE_BIN" "$SUT" "$REQPROTO" "$DOC" 2>&1)"; RC=$?
assert_eq       "inherited name doesn't satisfy required" 1 "$RC"
assert_contains "missing toString reported"     "$ERR" "missing required property 'toString'"

# --- summary ----------------------------------------------------------------
echo
echo "validate-findings: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
