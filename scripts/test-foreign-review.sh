#!/usr/bin/env bash
# test-foreign-review.sh — guard tests for foreign-review.sh.
#
# Fully offline: the codex CLI and curl are replaced by stub executables in a
# mktemp dir (CODEX_BIN / CURL_CMD test seams). Covers EVERY exit code
# (0/2/3/4/5/6), --probe for both backends in both directions, the
# never-write---out-on-failure contract, retry-once on transport-class
# failures, the watchdog (hanging stub TERMed, TERM-ignoring stub KILLed),
# the secret-scrub hard stop, the endpoint allowlist refusal, 13-findings
# rejection against a maxItems-12 schema, and bad-enum rejection.
#
# No network, no AI. Run after any change to foreign-review.sh or
# validate-findings.mjs.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUT="$SCRIPT_DIR/foreign-review.sh"

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
assert_not_contains() { # <desc> <haystack> <needle>
  case "$2" in *"$3"*) fail "$1 (unexpected: $3)" ;; *) pass "$1" ;; esac
}
assert_file_absent() { # <desc> <path>
  if [ -e "$2" ]; then fail "$1 ($2 exists)"; else pass "$1"; fi
}
assert_file_present() { # <desc> <path>
  if [ -s "$2" ]; then pass "$1"; else fail "$1 ($2 missing or empty)"; fi
}

# --- fixtures ----------------------------------------------------------------
DIR="$(mktemp -d "${TMPDIR:-/tmp}/fr-test.XXXXXX")"
STUBDIR="$DIR/stubs"
mkdir -p "$STUBDIR"
trap 'rm -rf "$DIR"' EXIT

# Isolate from any real key material on this machine.
unset OPENROUTER_API_KEY 2>/dev/null || true
unset FOREIGN_REVIEW_ENDPOINT 2>/dev/null || true
export FOREIGN_REVIEW_ENV_FILE="$DIR/no-such.env"

SCHEMA="$DIR/findings.schema.json"
cat > "$SCHEMA" <<'EOF'
{
  "type": "object",
  "additionalProperties": false,
  "required": ["verdict", "findings"],
  "properties": {
    "verdict": { "type": "string", "enum": ["approve", "approve_with_changes", "revise"] },
    "findings": {
      "type": "array",
      "maxItems": 12,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["id", "severity", "summary"],
        "properties": {
          "id": { "type": "string", "maxLength": 16 },
          "severity": { "type": "string", "enum": ["blocker", "major", "minor", "question"] },
          "summary": { "type": "string", "maxLength": 300 }
        }
      }
    }
  }
}
EOF

INPUT="$DIR/pack.md"
printf '# Review pack\nSENTINEL_PACK review payload.\nno secrets here.\n' > "$INPUT"

PROMPT="$DIR/prompt.md"
printf 'CUSTOM_PROMPT_SENTINEL reviewer instructions.\n' > "$PROMPT"

GOOD="$DIR/good-findings.json"
printf '{"verdict":"approve_with_changes","findings":[{"id":"F1","severity":"major","summary":"SENTINEL_FINDING one"}]}\n' > "$GOOD"

# 13 findings against a maxItems-12 schema.
THIRTEEN="$DIR/thirteen-findings.json"
items='{"id":"F1","severity":"minor","summary":"x"}'
i=2
while [ $i -le 13 ]; do
  items="$items,{\"id\":\"F$i\",\"severity\":\"minor\",\"summary\":\"x\"}"
  i=$((i + 1))
done
printf '{"verdict":"revise","findings":[%s]}\n' "$items" > "$THIRTEEN"

BADENUM="$DIR/bad-enum.json"
printf '{"verdict":"revise","findings":[{"id":"F1","severity":"catastrophic","summary":"x"}]}\n' > "$BADENUM"

# OpenRouter SSE streams (content is the stringified findings JSON, delivered as
# delta chunks). The request sets stream:true, so every fixture is a stream —
# there is no non-streaming envelope any more.
#
# sse_stream <content-file> -> a healthy stream: a keepalive COMMENT frame (the
# thing that must never count as liveness), the content as one delta, a
# finish_reason, and the [DONE] sentinel.
sse_stream() { # <content-file>
  printf ': OPENROUTER PROCESSING\n'
  # -c is load-bearing: an SSE frame is ONE line, and jq pretty-prints by default.
  jq -cRs '{choices:[{delta:{content:.}}]}' < "$1" | sed 's/^/data: /'
  printf 'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n'
  printf 'data: [DONE]\n'
}

GOOD_ENVELOPE="$DIR/good-stream.sse"
sse_stream "$GOOD" > "$GOOD_ENVELOPE"

# Stream that completes cleanly but carries no assistant content.
EMPTY_ENVELOPE="$DIR/empty-stream.sse"
printf 'data: {"choices":[{"delta":{}}]}\ndata: [DONE]\n' > "$EMPTY_ENVELOPE"

# Streaming-specific failure fixtures.
# TRUNC: content, then the stream just stops — no finish_reason, no [DONE].
TRUNC_STREAM="$DIR/trunc-stream.sse"
printf 'data: {"choices":[{"delta":{"content":"{\\"verdict\\": \\"par"}}]}\n' > "$TRUNC_STREAM"
# LENGTH: capped at max_tokens. Terminates properly, so ONLY finish_reason catches it.
LENGTH_STREAM="$DIR/length-stream.sse"
printf 'data: {"choices":[{"delta":{"content":"{\\"verdict\\":\\"x\\"}"}}]}\ndata: {"choices":[{"delta":{},"finish_reason":"length"}]}\ndata: [DONE]\n' > "$LENGTH_STREAM"
# STREAMERR: HTTP 200, error delivered inside the stream body.
STREAMERR_STREAM="$DIR/streamerr-stream.sse"
printf 'data: {"error":{"message":"upstream provider timeout"}}\n' > "$STREAMERR_STREAM"

# --- stub builders -----------------------------------------------------------
# Codex stub: consumes stdin (logged), finds -o FILE on argv, copies a canned
# response there. Argv is logged so tests can prove the pack is NOT on argv.
write_codex_stub() { # <path> <response-file>
  cat > "$1" <<EOF
#!/bin/bash
out=""; prev=""
for a in "\$@"; do
  [ "\$prev" = "-o" ] && out="\$a"
  prev="\$a"
done
cat > "$STUBDIR/last-stdin.txt"
printf '%s\n' "\$*" >> "$STUBDIR/codex-calls.log"
cp "$2" "\$out"
exit 0
EOF
  chmod +x "$1"
}

# Curl stub: logs argv, saves the --data @body payload, writes an envelope to
# the -o FILE, prints the HTTP code on stdout (mirroring -w '%{http_code}').
write_curl_stub() { # <path> <envelope-file> <http-code>
  cat > "$1" <<EOF
#!/bin/bash
out=""; body=""; prev=""
for a in "\$@"; do
  [ "\$prev" = "-o" ] && out="\$a"
  [ "\$prev" = "--data" ] && body="\$a"
  prev="\$a"
done
printf '%s\n' "\$*" >> "$STUBDIR/curl-calls.log"
case "\$body" in @*) cp "\${body#@}" "$STUBDIR/last-body.json" ;; esac
cp "$2" "\$out"
printf '%s' "$3"
exit 0
EOF
  chmod +x "$1"
}

reset_logs() {
  rm -f "$STUBDIR/codex-calls.log" "$STUBDIR/curl-calls.log" \
        "$STUBDIR/last-stdin.txt" "$STUBDIR/last-body.json" \
        "$STUBDIR"/*.marker "$STUBDIR"/*.pid 2>/dev/null
  return 0
}

CODEX_GOOD="$STUBDIR/codex-good"
write_codex_stub "$CODEX_GOOD" "$GOOD"
CODEX_13="$STUBDIR/codex-13"
write_codex_stub "$CODEX_13" "$THIRTEEN"
CODEX_BADENUM="$STUBDIR/codex-badenum"
write_codex_stub "$CODEX_BADENUM" "$BADENUM"
CURL_GOOD="$STUBDIR/curl-good"
write_curl_stub "$CURL_GOOD" "$GOOD_ENVELOPE" 200

# --- 1. usage errors (exit 2) ------------------------------------------------
echo "usage errors (exit 2)"
"$SUT" >/dev/null 2>&1
assert_eq "no args exits 2" 2 "$?"
"$SUT" --bogus >/dev/null 2>&1
assert_eq "unknown arg exits 2" 2 "$?"
"$SUT" --backend nonsense --mode plan --schema "$SCHEMA" --input "$INPUT" >/dev/null 2>&1
assert_eq "unknown backend exits 2" 2 "$?"
"$SUT" --backend openrouter: --mode plan --schema "$SCHEMA" --input "$INPUT" >/dev/null 2>&1
assert_eq "openrouter without model exits 2" 2 "$?"
"$SUT" --backend codex --mode wat --schema "$SCHEMA" --input "$INPUT" >/dev/null 2>&1
assert_eq "bad mode exits 2" 2 "$?"
"$SUT" --backend codex --schema "$SCHEMA" --input "$INPUT" >/dev/null 2>&1
assert_eq "missing mode exits 2" 2 "$?"
"$SUT" --backend codex --mode plan --input "$INPUT" >/dev/null 2>&1
assert_eq "missing schema exits 2" 2 "$?"
"$SUT" --backend codex --mode plan --schema "$DIR/nope.json" --input "$INPUT" >/dev/null 2>&1
assert_eq "nonexistent schema exits 2" 2 "$?"
"$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$DIR/nope.md" >/dev/null 2>&1
assert_eq "nonexistent input exits 2" 2 "$?"
"$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --timeout abc >/dev/null 2>&1
assert_eq "non-numeric timeout exits 2" 2 "$?"
"$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --timeout 0 >/dev/null 2>&1
assert_eq "zero timeout exits 2" 2 "$?"
"$SUT" --help >/dev/null 2>&1
assert_eq "--help exits 0" 0 "$?"
help_out="$("$SUT" --help 2>&1)"
assert_contains "usage documents exit 6" "$help_out" "6 secrets detected"

# --- 2. probe: both backends, both directions --------------------------------
echo "probe"
out="$(CODEX_BIN="$CODEX_GOOD" "$SUT" --backend codex --probe 2>&1)"; rc=$?
assert_eq       "probe codex available exits 0"    0 "$rc"
assert_contains "probe codex reports path"         "$out" "codex available"
out="$(CODEX_BIN="$DIR/no-such-codex" "$SUT" --backend codex --probe 2>&1)"; rc=$?
assert_eq       "probe codex unavailable exits 3"  3 "$rc"
assert_contains "probe codex says unavailable"     "$out" "codex unavailable"
out="$(OPENROUTER_API_KEY=dummykey CURL_CMD="$CURL_GOOD" "$SUT" --backend openrouter:test/model --probe 2>&1)"; rc=$?
assert_eq       "probe openrouter available exits 0" 0 "$rc"
assert_contains "probe openrouter names model"     "$out" "test/model"
out="$(CURL_CMD="$CURL_GOOD" "$SUT" --backend openrouter:test/model --probe 2>&1)"; rc=$?
assert_eq       "probe openrouter no key exits 3"  3 "$rc"
assert_contains "probe openrouter setup guidance"  "$out" "openrouter.ai"

# --- 3. backend unavailable (exit 3) -----------------------------------------
echo "backend unavailable (exit 3)"
out="$(CODEX_BIN="$DIR/no-such-codex" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o1.json" 2>&1)"; rc=$?
assert_eq          "codex missing exits 3"        3 "$rc"
assert_contains    "codex missing is loud"        "$out" "backend unavailable"
assert_file_absent "codex missing writes no out"  "$DIR/o1.json"
out="$(CURL_CMD="$CURL_GOOD" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o2.json" 2>&1)"; rc=$?
assert_eq          "no API key exits 3"           3 "$rc"
assert_contains    "no-key message names env file" "$out" "$FOREIGN_REVIEW_ENV_FILE"
assert_file_absent "no-key writes no out"         "$DIR/o2.json"

# --- 4. secret scrub (exit 6, hard stop, line numbers only) ------------------
echo "secret scrub (exit 6)"
SECRETS="$DIR/secret-pack.md"
cat > "$SECRETS" <<'EOF'
clean line one
sk-AAAAAAAAAAAAAAAAAAAAAAAAAAAA
clean line three
AKIA1234567890ABCDEF was here
ghp_ZZZZZZZZZZZZZZZZZZZZZZZZ token
-----BEGIN RSA PRIVATE KEY-----
MY_SECRET_TOKEN=abcdefghij0123456789
EOF
reset_logs
out="$(CODEX_BIN="$CODEX_GOOD" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$SECRETS" --out "$DIR/o3.json" 2>&1)"; rc=$?
assert_eq           "secrets exit 6"                 6 "$rc"
assert_contains     "reports SECRETS DETECTED"       "$out" "SECRETS DETECTED"
assert_contains     "reports line numbers"           "$out" "2 4 5 6 7"
assert_not_contains "never prints the sk- value"     "$out" "sk-AAAA"
assert_not_contains "never prints the AKIA value"    "$out" "AKIA1234567890ABCDEF"
assert_not_contains "never prints the ghp value"     "$out" "ghp_ZZZZ"
assert_not_contains "never prints the env value"     "$out" "abcdefghij0123456789"
assert_contains     "says nothing was sent"          "$out" "NOTHING was sent"
assert_file_absent  "backend never invoked"          "$STUBDIR/codex-calls.log"
assert_file_absent  "no out written"                 "$DIR/o3.json"
assert_file_absent  "no raw written"                 "$DIR/o3.json.raw"

# secrets in the --prompt file are caught too
reset_logs
out="$(CODEX_BIN="$CODEX_GOOD" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --prompt "$SECRETS" --out "$DIR/o3b.json" 2>&1)"; rc=$?
assert_eq          "secret prompt exits 6"           6 "$rc"
assert_file_absent "secret prompt: backend not invoked" "$STUBDIR/codex-calls.log"

# --- 5. endpoint allowlist refusal (exit 2, key never attached) ---------------
echo "endpoint allowlist"
reset_logs
out="$(OPENROUTER_API_KEY=dummykey FOREIGN_REVIEW_ENDPOINT="https://evil.example.com/api/v1/chat/completions" CURL_CMD="$CURL_GOOD" \
      "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o4.json" 2>&1)"; rc=$?
assert_eq           "non-allowlisted endpoint exits 2" 2 "$rc"
assert_contains     "refusal is loud"                  "$out" "REFUSING"
assert_contains     "refusal names the endpoint"       "$out" "evil.example.com"
assert_file_absent  "curl never invoked"               "$STUBDIR/curl-calls.log"
assert_file_absent  "no out written"                   "$DIR/o4.json"
# lookalike host must not pass the allowlist
out="$(OPENROUTER_API_KEY=dummykey FOREIGN_REVIEW_ENDPOINT="https://openrouter.ai.evil.com/api" CURL_CMD="$CURL_GOOD" \
      "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" 2>&1)"; rc=$?
assert_eq "lookalike host refused" 2 "$rc"
# an openrouter.ai path override IS allowed
reset_logs
OPENROUTER_API_KEY=dummykey FOREIGN_REVIEW_ENDPOINT="https://openrouter.ai/api/v1/chat/completions" CURL_CMD="$CURL_GOOD" \
  "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o4b.json" --quiet >/dev/null 2>&1
assert_eq "openrouter.ai endpoint accepted" 0 "$?"

# --- 6. codex happy path (exit 0) --------------------------------------------
echo "codex happy path"
reset_logs
OUT="$DIR/codex-out.json"
out="$(CODEX_BIN="$CODEX_GOOD" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$OUT" 2>&1)"; rc=$?
assert_eq           "exits 0"                       0 "$rc"
assert_file_present "--out written"                 "$OUT"
assert_contains     "--out has the findings"        "$(cat "$OUT")" "SENTINEL_FINDING"
assert_file_present "raw preserved at <out>.raw"    "$OUT.raw"
calls="$(cat "$STUBDIR/codex-calls.log")"
assert_contains     "read-only sandbox flag"        "$calls" "exec -s read-only"
assert_contains     "skip-git-repo-check flag"      "$calls" "--skip-git-repo-check"
assert_contains     "schema passed to codex"        "$calls" "--output-schema"
assert_not_contains "pack NOT on argv"              "$calls" "SENTINEL_PACK"
stdin_seen="$(cat "$STUBDIR/last-stdin.txt")"
assert_contains     "pack fed via stdin"            "$stdin_seen" "SENTINEL_PACK"
assert_contains     "default plan instruction line" "$stdin_seen" "external plan reviewer"

# no --out: findings go to stdout, raw at a temp path
reset_logs
out="$(CODEX_BIN="$CODEX_GOOD" "$SUT" --backend codex --mode code --schema "$SCHEMA" --input "$INPUT" 2>"$DIR/stderr.txt")"; rc=$?
assert_eq       "no --out exits 0"              0 "$rc"
assert_contains "findings on stdout"            "$out" "SENTINEL_FINDING"
assert_contains "raw temp path reported"        "$(cat "$DIR/stderr.txt")" "raw preserved at"
assert_contains "default code instruction line" "$(cat "$STUBDIR/last-stdin.txt")" "external code reviewer"

# --prompt replaces the default instruction line
reset_logs
CODEX_BIN="$CODEX_GOOD" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --prompt "$PROMPT" --out "$DIR/o5.json" --quiet >/dev/null 2>&1
stdin_seen="$(cat "$STUBDIR/last-stdin.txt")"
assert_contains     "--prompt content on stdin"     "$stdin_seen" "CUSTOM_PROMPT_SENTINEL"
assert_not_contains "--prompt suppresses default"   "$stdin_seen" "external plan reviewer"

# --- 7. openrouter happy path (exit 0) ---------------------------------------
echo "openrouter happy path"
reset_logs
OUT="$DIR/or-out.json"
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_GOOD" "$SUT" --backend openrouter:moonshotai/kimi-k2 --mode code --schema "$SCHEMA" --input "$INPUT" --out "$OUT" 2>&1)"; rc=$?
assert_eq           "exits 0"                    0 "$rc"
assert_file_present "--out written"              "$OUT"
assert_contains     "--out has the findings"     "$(cat "$OUT")" "SENTINEL_FINDING"
assert_file_present "raw preserved at <out>.raw" "$OUT.raw"
calls="$(cat "$STUBDIR/curl-calls.log")"
assert_contains     "key attached as bearer"     "$calls" "Bearer stubkey"
assert_contains     "default endpoint used"      "$calls" "https://openrouter.ai/api/v1/chat/completions"
body="$(cat "$STUBDIR/last-body.json")"
assert_contains     "body carries the model id"  "$body" "moonshotai/kimi-k2"
assert_contains     "body sets temperature 0.2"  "$body" '"temperature": 0.2'
assert_contains     "body demands strict json_schema" "$body" '"strict": true'
assert_contains     "body embeds the schema"     "$body" '"maxItems": 12'
assert_contains     "body carries the pack"      "$body" "SENTINEL_PACK"

# key sourced from FOREIGN_REVIEW_ENV_FILE when the env var is absent
reset_logs
ENVF="$DIR/foreign-review.env"
printf 'OPENROUTER_API_KEY="filekey123"\n' > "$ENVF"
FOREIGN_REVIEW_ENV_FILE="$ENVF" CURL_CMD="$CURL_GOOD" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o6.json" --quiet >/dev/null 2>&1
assert_eq       "env-file key exits 0"        0 "$?"
assert_contains "env-file key attached"       "$(cat "$STUBDIR/curl-calls.log")" "Bearer filekey123"

# --- 8. schema-invalid output (exit 5, out never written, raw preserved) -----
echo "schema-invalid output (exit 5)"
OUT="$DIR/invalid-out.json"
out="$(CODEX_BIN="$CODEX_13" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$OUT" 2>&1)"; rc=$?
assert_eq           "13 findings vs maxItems-12 exits 5" 5 "$rc"
assert_contains     "reports validation failure"         "$out" "FAILED schema validation"
assert_contains     "validator detail surfaced"          "$out" "exceeds maxItems 12"
assert_file_absent  "--out NOT written"                  "$OUT"
assert_file_present "raw preserved for inspection"       "$OUT.raw"
rm -f "$OUT.raw"

out="$(CODEX_BIN="$CODEX_BADENUM" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$OUT" 2>&1)"; rc=$?
assert_eq           "bad enum exits 5"           5 "$rc"
assert_contains     "enum violation surfaced"    "$out" "not one of enum"
assert_file_absent  "--out NOT written (enum)"   "$OUT"
rm -f "$OUT.raw"

# --- 9. transport-class failure: retry ONCE ----------------------------------
echo "transport retry"
# codex: stream disconnect on the first call, success on the second
CODEX_FLAKY="$STUBDIR/codex-flaky"
cat > "$CODEX_FLAKY" <<EOF
#!/bin/bash
cat > /dev/null
printf '%s\n' "\$*" >> "$STUBDIR/codex-calls.log"
if [ ! -f "$STUBDIR/flaky.marker" ]; then
  touch "$STUBDIR/flaky.marker"
  echo "ERROR: stream disconnected before completion" >&2
  exit 1
fi
out=""; prev=""
for a in "\$@"; do [ "\$prev" = "-o" ] && out="\$a"; prev="\$a"; done
cp "$GOOD" "\$out"
exit 0
EOF
chmod +x "$CODEX_FLAKY"
reset_logs
OUT="$DIR/retry-out.json"
out="$(CODEX_BIN="$CODEX_FLAKY" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$OUT" 2>&1)"; rc=$?
assert_eq           "flaky codex recovers (exit 0)" 0 "$rc"
assert_contains     "retry was announced"           "$out" "retrying once"
assert_eq           "exactly two attempts"          2 "$(wc -l < "$STUBDIR/codex-calls.log" | tr -d ' ')"
assert_file_present "out written after retry"       "$OUT"

# codex: persistent stream disconnect -> retry once, then exit 4
CODEX_DEAD="$STUBDIR/codex-dead"
cat > "$CODEX_DEAD" <<EOF
#!/bin/bash
cat > /dev/null
printf '%s\n' "\$*" >> "$STUBDIR/codex-calls.log"
echo "ERROR: stream disconnected before completion" >&2
exit 1
EOF
chmod +x "$CODEX_DEAD"
reset_logs
OUT="$DIR/dead-out.json"
out="$(CODEX_BIN="$CODEX_DEAD" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$OUT" 2>&1)"; rc=$?
assert_eq          "persistent transport failure exits 4" 4 "$rc"
assert_eq          "retried exactly once (two attempts)"  2 "$(wc -l < "$STUBDIR/codex-calls.log" | tr -d ' ')"
assert_file_absent "no out on failure"                    "$OUT"

# codex: NON-transport failure is not retried
CODEX_BOOM="$STUBDIR/codex-boom"
cat > "$CODEX_BOOM" <<EOF
#!/bin/bash
cat > /dev/null
printf '%s\n' "\$*" >> "$STUBDIR/codex-calls.log"
echo "ERROR: model refused" >&2
exit 1
EOF
chmod +x "$CODEX_BOOM"
reset_logs
out="$(CODEX_BIN="$CODEX_BOOM" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o7.json" 2>&1)"; rc=$?
assert_eq          "non-transport failure exits 4"  4 "$rc"
assert_eq          "non-transport NOT retried"      1 "$(wc -l < "$STUBDIR/codex-calls.log" | tr -d ' ')"
assert_contains    "backend stderr surfaced"        "$out" "model refused"
assert_file_absent "no out on failure"              "$DIR/o7.json"

# curl: transport exit 56 once, then success
CURL_FLAKY="$STUBDIR/curl-flaky"
cat > "$CURL_FLAKY" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$STUBDIR/curl-calls.log"
if [ ! -f "$STUBDIR/curl-flaky.marker" ]; then
  touch "$STUBDIR/curl-flaky.marker"
  exit 56
fi
out=""; prev=""
for a in "\$@"; do [ "\$prev" = "-o" ] && out="\$a"; prev="\$a"; done
cp "$GOOD_ENVELOPE" "\$out"
printf '200'
exit 0
EOF
chmod +x "$CURL_FLAKY"
reset_logs
OUT="$DIR/or-retry.json"
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_FLAKY" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$OUT" 2>&1)"; rc=$?
assert_eq "flaky curl recovers (exit 0)"  0 "$rc"
assert_eq "curl retried exactly once"     2 "$(wc -l < "$STUBDIR/curl-calls.log" | tr -d ' ')"

# curl: persistent transport failure -> exit 4 after one retry
CURL_DEAD="$STUBDIR/curl-dead"
cat > "$CURL_DEAD" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$STUBDIR/curl-calls.log"
exit 56
EOF
chmod +x "$CURL_DEAD"
reset_logs
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_DEAD" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o8.json" 2>&1)"; rc=$?
assert_eq          "persistent curl failure exits 4" 4 "$rc"
assert_eq          "curl attempts capped at two"     2 "$(wc -l < "$STUBDIR/curl-calls.log" | tr -d ' ')"
assert_file_absent "no out on curl failure"          "$DIR/o8.json"

# --- 10. HTTP-level failures (exit 4) ----------------------------------------
echo "HTTP failures (exit 4)"
CURL_500="$STUBDIR/curl-500"
printf '{"error":{"message":"upstream sad"}}\n' > "$DIR/err-body.json"
write_curl_stub "$CURL_500" "$DIR/err-body.json" 500
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_500" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o9.json" 2>&1)"; rc=$?
assert_eq          "HTTP 500 exits 4"        4 "$rc"
assert_contains    "HTTP code reported"      "$out" "HTTP 500"
assert_file_absent "no out on HTTP failure"  "$DIR/o9.json"

CURL_EMPTY="$STUBDIR/curl-empty"
write_curl_stub "$CURL_EMPTY" "$EMPTY_ENVELOPE" 200
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_EMPTY" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o10.json" 2>&1)"; rc=$?
assert_eq          "empty envelope exits 4"  4 "$rc"
assert_contains    "empty content reported"  "$out" "no assistant content"
assert_file_absent "no out on empty content" "$DIR/o10.json"

# --- 10b. streaming-specific failures (exit 4) -------------------------------
# Every case here returns HTTP 200 with a well-formed stream. They are exactly
# the failures a non-streaming reader could not see.
echo "SSE stream failures (exit 4)"

# Truncated: content arrived, then the stream stopped. Must fail as TRUNCATED
# rather than falling through to the validator, where a cut-off JSON string
# surfaces as a confusing schema error instead of the real cause.
CURL_TRUNC="$STUBDIR/curl-trunc"
write_curl_stub "$CURL_TRUNC" "$TRUNC_STREAM" 200
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_TRUNC" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o13.json" 2>&1)"; rc=$?
assert_eq          "truncated stream exits 4"      4 "$rc"
assert_contains    "truncation named, not schema"  "$out" "TRUNCATED"
assert_file_absent "no out on truncated stream"    "$DIR/o13.json"

# Capped at max_tokens: terminates cleanly WITH [DONE], so only finish_reason
# distinguishes it from a good response.
CURL_LENGTH="$STUBDIR/curl-length"
write_curl_stub "$CURL_LENGTH" "$LENGTH_STREAM" 200
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_LENGTH" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o14.json" 2>&1)"; rc=$?
assert_eq          "max_tokens cap exits 4"     4 "$rc"
assert_contains    "cap reported with limit"    "$out" "max_tokens"
assert_file_absent "no out on capped output"    "$DIR/o14.json"

# Error inside a 200 body.
CURL_STREAMERR="$STUBDIR/curl-streamerr"
write_curl_stub "$CURL_STREAMERR" "$STREAMERR_STREAM" 200
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_STREAMERR" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o15.json" 2>&1)"; rc=$?
assert_eq          "mid-stream error exits 4"     4 "$rc"
assert_contains    "provider message surfaced"    "$out" "upstream provider timeout"
assert_file_absent "no out on mid-stream error"   "$DIR/o15.json"

# --- 10c. THE regression test: keepalive-only stall --------------------------
# A stub that emits ': OPENROUTER PROCESSING' comment frames forever. Wire bytes
# keep flowing, so a byte-rate watchdog (curl --speed-limit, or polling the raw
# file size) NEVER fires and the request runs to the wall clock. The idle window
# is measured on parsed delta.content instead, which stays at zero here.
CURL_KEEPALIVE="$STUBDIR/curl-keepalive"
cat > "$CURL_KEEPALIVE" <<EOF
#!/bin/bash
out=""; prev=""
for a in "\$@"; do [ "\$prev" = "-o" ] && out="\$a"; prev="\$a"; done
printf '%s\n' "\$*" >> "$STUBDIR/curl-calls.log"
while :; do printf ': OPENROUTER PROCESSING\n' >> "\$out"; sleep 1; done
EOF
chmod +x "$CURL_KEEPALIVE"
reset_logs
start=$(date +%s)
out="$(OPENROUTER_API_KEY=stubkey CURL_CMD="$CURL_KEEPALIVE" "$SUT" --backend openrouter:test/model --mode code --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o16.json" --timeout 20 --idle-timeout 3 2>&1)"; rc=$?
elapsed=$(( $(date +%s) - start ))
assert_eq          "keepalive stall exits 4"        4 "$rc"
assert_contains    "reported as stalled, not slow"  "$out" "no content for"
assert_file_absent "no out on keepalive stall"      "$DIR/o16.json"
# The whole point: it must die on the IDLE window (~3-8s), not the 20s ceiling.
if [ "$elapsed" -lt 15 ]; then
  pass "idle abort beat the wall clock (${elapsed}s < 20s)"
else
  fail "idle abort beat the wall clock" "ran ${elapsed}s — wire-byte keepalives defeated the idle window"
fi

# --- 11. watchdog: hanging backend killed (exit 4) ---------------------------
echo "watchdog"
CODEX_HANG="$STUBDIR/codex-hang"
cat > "$CODEX_HANG" <<'EOF'
#!/bin/bash
cat > /dev/null
sleep 60
EOF
chmod +x "$CODEX_HANG"
start=$SECONDS
out="$(CODEX_BIN="$CODEX_HANG" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o11.json" --timeout 1 2>&1)"; rc=$?
elapsed=$((SECONDS - start))
assert_eq          "hanging backend exits 4"     4 "$rc"
assert_contains    "timeout reported"            "$out" "timed out after 1s"
assert_file_absent "no out after timeout"        "$DIR/o11.json"
if [ "$elapsed" -le 10 ]; then pass "watchdog fired promptly (${elapsed}s)"; else fail "watchdog too slow (${elapsed}s)"; fi

# TERM-ignoring backend gets KILLed
CODEX_IGNORE="$STUBDIR/codex-ignore-term"
cat > "$CODEX_IGNORE" <<EOF
#!/bin/bash
echo \$\$ > "$STUBDIR/ignore-term.pid"
trap '' TERM
cat > /dev/null
while :; do sleep 1; done
EOF
chmod +x "$CODEX_IGNORE"
reset_logs
start=$SECONDS
out="$(CODEX_BIN="$CODEX_IGNORE" "$SUT" --backend codex --mode plan --schema "$SCHEMA" --input "$INPUT" --out "$DIR/o12.json" --timeout 1 2>&1)"; rc=$?
elapsed=$((SECONDS - start))
assert_eq "TERM-ignoring backend exits 4" 4 "$rc"
if [ "$elapsed" -le 12 ]; then pass "KILL escalation prompt (${elapsed}s)"; else fail "KILL escalation too slow (${elapsed}s)"; fi
stub_pid="$(cat "$STUBDIR/ignore-term.pid" 2>/dev/null)"
sleep 1
if [ -n "$stub_pid" ] && kill -0 "$stub_pid" 2>/dev/null; then
  fail "TERM-ignoring stub actually killed (pid $stub_pid survived)"
  kill -KILL "$stub_pid" 2>/dev/null
else
  pass "TERM-ignoring stub actually killed"
fi
assert_file_absent "no out after KILL" "$DIR/o12.json"

# --- summary -----------------------------------------------------------------
echo
echo "foreign-review: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
