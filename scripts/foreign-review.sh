#!/usr/bin/env bash
# foreign-review.sh — backend-agnostic runner for FOREIGN-model reviews.
#
# One entry point for sending a review pack (plan pack or code-review pack) to
# a model from a different family and getting back schema-valid JSON findings.
# Backends:
#   codex               OpenAI Codex CLI: `codex exec -s read-only
#                       --skip-git-repo-check --output-schema <schema>`, run
#                       from the repo root, the pack fed via STDIN (never argv
#                       — OS arg limits; verified: `codex exec` with no PROMPT
#                       argument reads its instructions from stdin).
#   openrouter:<model>  OpenRouter chat completions: curl POST with
#                       response_format json_schema (strict), temperature 0.2.
#                       API key from $OPENROUTER_API_KEY, else read from
#                       FOREIGN_REVIEW_ENV_FILE (default
#                       ~/.claude/foreign-review.env, chmod 600, never
#                       committed). ENDPOINT ALLOWLIST: the key is only ever
#                       attached to https://openrouter.ai/... — any
#                       FOREIGN_REVIEW_ENDPOINT outside openrouter.ai is
#                       refused loudly (exit 2). [ext-review codex:MMO-001]
#
# Fail LOUD, never fabricate, never substitute a backend. Raw backend output is
# ALWAYS preserved at <out>.raw (or a temp path when no --out); --out is
# written ONLY after the output passes scripts/validate-findings.mjs (a real
# validator, never jq [ext-review codex:MMO-002]).
#
# SECRET SCRUB [ext-review codex:MMO-001]: before ANY third-party send, the
# input (and --prompt file, if given) is scanned for key-shaped strings
# (sk-…, AKIA…, ghp_/gho_ tokens, PRIVATE KEY blocks, .env-style lines). Any
# hit is a HARD STOP: exit 6, reporting the LINE NUMBERS only — never the
# values. Redact and re-run; there is no override flag.
#
# Portable timeout [ext-review codex:MMO-009]: macOS has no timeout(1) — the
# backend runs in its own process group under a poller watchdog that sends
# TERM, then KILL. One automatic retry on transport-class failures only (curl
# exit 18/52/56, or codex "stream disconnected" — observed live), then exit 4.
#
# STREAMING (openrouter): the request sets stream:true and liveness is measured
# on PARSED ASSISTANT CONTENT, never on wire bytes — OpenRouter pads upstream
# stalls with `: OPENROUTER PROCESSING` comment frames, so a byte-rate check
# (curl --speed-limit, or polling the response file's size) stays green through
# exactly the hang it is meant to catch. Two distinct aborts, which curl itself
# cannot tell apart (both are its exit 28): 124 wall clock, 125 content-idle.
# A truncated stream is caught by the [DONE] sentinel and finish_reason rather
# than by letting JSON.parse discover it downstream.
#
# Usage:
#   foreign-review.sh --backend codex|openrouter:<model> --mode plan|code
#                     --schema FILE --input FILE [--out FILE] [--prompt FILE]
#                     [--timeout SECS] [--idle-timeout SECS] [--max-tokens N]
#                     [--probe] [--quiet]
#     --backend   codex, or openrouter:<model-id> (e.g. openrouter:moonshotai/kimi-k2)
#     --mode      plan (plan-stage review) | code (PR-stage review)
#     --schema    JSON Schema (restricted dialect) the findings must satisfy
#     --input     the review pack to send (charter-first memory pack + payload)
#     --out       write validated findings JSON here (raw always at <out>.raw)
#     --prompt    reviewer prompt file, prepended to the pack on stdin
#     --timeout   wall-clock seconds for the backend call (default 600)
#     --idle-timeout  abort after N seconds with no ASSISTANT CONTENT (default
#                 60; openrouter only, immune to SSE keepalive frames)
#     --max-tokens    cap the generation (default 8000)
#     --probe     only report whether the backend is usable (exit 0/3); needs
#                 just --backend
#     --quiet     suppress informational notes on stderr (errors always print)
#
# Exit codes:
#   0  valid review written (stdout when no --out)
#   2  usage error / endpoint-allowlist refusal
#   3  backend unavailable (binary not found, no API key, missing dependency)
#   4  backend call failed (transport, timeout/killed, non-200, empty output)
#   5  backend output failed schema validation (raw preserved for inspection)
#   6  SECRETS DETECTED in the input — hard stop, nothing was sent
#
# Test seams (mirroring memory-context.sh conventions): CODEX_BIN, CURL_CMD,
# FOREIGN_REVIEW_ENDPOINT, FOREIGN_REVIEW_ENV_FILE, NODE_BIN.
#
# bash 3.2 + curl + jq + node. No network beyond the one backend call.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: foreign-review.sh --backend codex|openrouter:<model> --mode plan|code
                         --schema FILE --input FILE [--out FILE] [--prompt FILE]
                         [--timeout SECS] [--idle-timeout SECS] [--max-tokens N]
                         [--probe] [--quiet]
  Send a review pack to a foreign-model backend; validated JSON findings out.
  Exit: 0 valid review / 2 usage or endpoint refusal / 3 backend unavailable /
        4 backend call failed / 5 schema-invalid output /
        6 secrets detected in input (hard stop — nothing sent; redact and re-run)
EOF
}

note() { [ "$QUIET" -eq 0 ] && printf 'foreign-review: %s\n' "$1" >&2; return 0; }
err()  { printf 'foreign-review: %s\n' "$1" >&2; }

# --- args --------------------------------------------------------------------
BACKEND_ARG=""
MODE=""
SCHEMA=""
INPUT=""
OUT_FILE=""
PROMPT_FILE=""
# Wall clock vs idle window. These move together and the reasoning matters:
#
# The old default was 300s with NO idle detection, so the ceiling was the only
# bound — and a real Kimi plan review measures ~240s, i.e. 80% of it. That is
# why reviews "time out often": healthy generations were racing the only guard.
#
# Raising the ceiling was previously unsafe because a stalled provider keeps
# emitting `: OPENROUTER PROCESSING` keepalives, so any wire-byte liveness check
# stays green and a hang would run the full ceiling. The idle window below is
# measured on parsed assistant content instead (see sse_content), which is
# immune to keepalives — proven by the keepalive-only stall test, which aborts
# in ~4s. With a real hang now dying at IDLE_TIMEOUT, the ceiling only ever
# bounds genuinely long generations, so it can afford to be generous.
#
# Net effect vs. the old behavior: slow-but-healthy succeeds instead of dying at
# 300s, and an actual hang fails in 60s instead of 300s. Both directions improve.
TIMEOUT=600
IDLE_TIMEOUT=60
IDLE_EXPLICIT=0
MAX_TOKENS=8000
PROBE=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --backend) [ $# -ge 2 ] || { err "--backend needs a value"; exit 2; }
               BACKEND_ARG="$2"; shift 2 ;;
    --mode)    [ $# -ge 2 ] || { err "--mode needs plan|code"; exit 2; }
               MODE="$2"; shift 2 ;;
    --schema)  [ $# -ge 2 ] || { err "--schema needs a FILE"; exit 2; }
               SCHEMA="$2"; shift 2 ;;
    --input)   [ $# -ge 2 ] || { err "--input needs a FILE"; exit 2; }
               INPUT="$2"; shift 2 ;;
    --out)     [ $# -ge 2 ] || { err "--out needs a FILE"; exit 2; }
               OUT_FILE="$2"; shift 2 ;;
    --prompt)  [ $# -ge 2 ] || { err "--prompt needs a FILE"; exit 2; }
               PROMPT_FILE="$2"; shift 2 ;;
    --timeout) [ $# -ge 2 ] || { err "--timeout needs SECS"; exit 2; }
               TIMEOUT="$2"; shift 2 ;;
    --idle-timeout) [ $# -ge 2 ] || { err "--idle-timeout needs SECS"; exit 2; }
               IDLE_TIMEOUT="$2"; IDLE_EXPLICIT=1; shift 2 ;;
    --max-tokens)   [ $# -ge 2 ] || { err "--max-tokens needs N"; exit 2; }
               MAX_TOKENS="$2"; shift 2 ;;
    --probe)   PROBE=1; shift ;;
    --quiet)   QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown arg: $1"; usage; exit 2 ;;
  esac
done

[ -n "$BACKEND_ARG" ] || { err "--backend is required"; usage; exit 2; }

BACKEND=""
MODEL=""
case "$BACKEND_ARG" in
  codex)         BACKEND="codex" ;;
  openrouter:*)  BACKEND="openrouter"; MODEL="${BACKEND_ARG#openrouter:}"
                 [ -n "$MODEL" ] || { err "--backend openrouter:<model> needs a model id"; exit 2; } ;;
  *) err "unknown backend '$BACKEND_ARG' (want codex or openrouter:<model>)"; usage; exit 2 ;;
esac

CODEX_BIN="${CODEX_BIN:-codex}"
CURL_CMD="${CURL_CMD:-curl}"
NODE_BIN="${NODE_BIN:-node}"
ENV_FILE="${FOREIGN_REVIEW_ENV_FILE:-$HOME/.claude/foreign-review.env}"
ENDPOINT="${FOREIGN_REVIEW_ENDPOINT:-https://openrouter.ai/api/v1/chat/completions}"

# resolve_openrouter_key — sets OR_KEY and OR_KEY_SOURCE; returns 1 if absent.
OR_KEY=""
OR_KEY_SOURCE=""
resolve_openrouter_key() {
  if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    OR_KEY="$OPENROUTER_API_KEY"; OR_KEY_SOURCE="env"; return 0
  fi
  if [ -f "$ENV_FILE" ]; then
    # Parse (never source) the env file: OPENROUTER_API_KEY=..., optional quotes.
    OR_KEY="$(sed -n 's/^OPENROUTER_API_KEY=//p' "$ENV_FILE" | head -n 1 \
              | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")"
    if [ -n "$OR_KEY" ]; then OR_KEY_SOURCE="$ENV_FILE"; return 0; fi
  fi
  return 1
}

# --- probe: availability only, exit 0/3 -------------------------------------
if [ "$PROBE" -eq 1 ]; then
  case "$BACKEND" in
    codex)
      if path="$(command -v "$CODEX_BIN" 2>/dev/null)"; then
        printf 'probe: codex available (%s)\n' "$path"
        exit 0
      fi
      err "probe: codex unavailable — '$CODEX_BIN' not found on PATH"
      exit 3
      ;;
    openrouter)
      if ! command -v "$CURL_CMD" >/dev/null 2>&1; then
        err "probe: openrouter unavailable — curl ('$CURL_CMD') not found"
        exit 3
      fi
      if ! command -v jq >/dev/null 2>&1; then
        err "probe: openrouter unavailable — jq not found (needed to build the request body)"
        exit 3
      fi
      if resolve_openrouter_key; then
        printf 'probe: openrouter available (model %s, key from %s)\n' "$MODEL" "$OR_KEY_SOURCE"
        exit 0
      fi
      err "probe: openrouter unavailable — no OPENROUTER_API_KEY in env and none in $ENV_FILE"
      err "  setup: create the key at openrouter.ai, then: printf 'OPENROUTER_API_KEY=<key>\\n' > $ENV_FILE && chmod 600 $ENV_FILE"
      exit 3
      ;;
  esac
fi

# --- non-probe arg validation ------------------------------------------------
case "$MODE" in
  plan|code) : ;;
  "")        err "--mode is required (plan|code)"; usage; exit 2 ;;
  *)         err "unknown --mode '$MODE' (want plan|code)"; usage; exit 2 ;;
esac
[ -n "$SCHEMA" ] || { err "--schema is required"; usage; exit 2; }
[ -f "$SCHEMA" ] || { err "schema file not found: $SCHEMA"; exit 2; }
[ -n "$INPUT" ]  || { err "--input is required"; usage; exit 2; }
[ -f "$INPUT" ]  || { err "input file not found: $INPUT"; exit 2; }
if [ -n "$PROMPT_FILE" ] && [ ! -f "$PROMPT_FILE" ]; then
  err "prompt file not found: $PROMPT_FILE"; exit 2
fi
case "$TIMEOUT" in
  ''|*[!0-9]*) err "--timeout must be a positive integer (got '$TIMEOUT')"; exit 2 ;;
  0)           err "--timeout must be a positive integer (got '0')"; exit 2 ;;
esac
case "$IDLE_TIMEOUT" in
  ''|*[!0-9]*) err "--idle-timeout must be a positive integer (got '$IDLE_TIMEOUT')"; exit 2 ;;
  0)           err "--idle-timeout must be a positive integer (got '0')"; exit 2 ;;
esac
case "$MAX_TOKENS" in
  ''|*[!0-9]*) err "--max-tokens must be a positive integer (got '$MAX_TOKENS')"; exit 2 ;;
  0)           err "--max-tokens must be a positive integer (got '0')"; exit 2 ;;
esac
# Idle abort is openrouter-only and is only meaningful strictly inside the wall
# clock. An EXPLICIT --idle-timeout that can never fire is a usage error; the
# DEFAULT silently clamps, so a short --timeout stays legal (codex tests use
# --timeout 1, and the default idle window must not turn that into exit 2).
if [ "$IDLE_TIMEOUT" -ge "$TIMEOUT" ]; then
  if [ "$IDLE_EXPLICIT" -eq 1 ]; then
    err "--idle-timeout ($IDLE_TIMEOUT) must be less than --timeout ($TIMEOUT), or it can never fire"
    exit 2
  fi
  IDLE_TIMEOUT=$((TIMEOUT - 1))
  [ "$IDLE_TIMEOUT" -lt 1 ] && IDLE_TIMEOUT=1
fi

VALIDATOR="$SCRIPT_DIR/validate-findings.mjs"
[ -f "$VALIDATOR" ] || { err "validator missing: $VALIDATOR"; exit 2; }
command -v "$NODE_BIN" >/dev/null 2>&1 || { err "node ('$NODE_BIN') not found — required for schema validation"; exit 3; }

abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$PWD" "$1" ;; esac; }
SCHEMA_ABS="$(abspath "$SCHEMA")"

# --- backend availability (fail loud, never substitute) ----------------------
case "$BACKEND" in
  codex)
    command -v "$CODEX_BIN" >/dev/null 2>&1 || {
      err "backend unavailable: codex ('$CODEX_BIN') not found on PATH — install the Codex CLI or set CODEX_BIN"
      exit 3
    }
    ;;
  openrouter)
    command -v "$CURL_CMD" >/dev/null 2>&1 || { err "backend unavailable: curl ('$CURL_CMD') not found"; exit 3; }
    command -v jq >/dev/null 2>&1 || { err "backend unavailable: jq not found (needed to build the request body)"; exit 3; }
    resolve_openrouter_key || {
      err "backend unavailable: no OPENROUTER_API_KEY in env and none in $ENV_FILE"
      err "  setup: create the key at openrouter.ai, then: printf 'OPENROUTER_API_KEY=<key>\\n' > $ENV_FILE && chmod 600 $ENV_FILE"
      exit 3
    }
    # ENDPOINT ALLOWLIST: never attach the key anywhere but openrouter.ai.
    case "$ENDPOINT" in
      https://openrouter.ai/*) : ;;
      *)
        err "REFUSING to attach the OpenRouter API key to non-allowlisted endpoint: $ENDPOINT"
        err "  only https://openrouter.ai/... is permitted (FOREIGN_REVIEW_ENDPOINT override must stay on openrouter.ai)"
        exit 2
        ;;
    esac
    ;;
esac

# --- secret scrub: HARD STOP before anything leaves the machine --------------
# Reports line numbers ONLY — the matching values are never echoed.
scan_secrets() { # <file> -> space-separated sorted unique line numbers
  {
    grep -nE 'sk-[A-Za-z0-9]{20,}'              "$1" 2>/dev/null
    grep -nE 'AKIA[0-9A-Z]{16}'                 "$1" 2>/dev/null
    grep -nE 'gh[po]_[A-Za-z0-9]{16,}'          "$1" 2>/dev/null
    grep -nE 'BEGIN [A-Z ]*PRIVATE KEY'         "$1" 2>/dev/null
    grep -nE '^[A-Z_]{4,}=[^[:space:]]{16,}'    "$1" 2>/dev/null
  } | cut -d: -f1 | sort -n | uniq | tr '\n' ' ' | sed 's/ $//'
}

SECRET_HIT=0
hits="$(scan_secrets "$INPUT")"
if [ -n "$hits" ]; then
  err "SECRETS DETECTED in input $INPUT at line(s): $hits"
  SECRET_HIT=1
fi
if [ -n "$PROMPT_FILE" ]; then
  hits="$(scan_secrets "$PROMPT_FILE")"
  if [ -n "$hits" ]; then
    err "SECRETS DETECTED in prompt $PROMPT_FILE at line(s): $hits"
    SECRET_HIT=1
  fi
fi
if [ "$SECRET_HIT" -eq 1 ]; then
  err "hard stop: NOTHING was sent. Redact the flagged lines (values are never printed) and re-run."
  exit 6
fi

# --- working files -----------------------------------------------------------
SEND_FILE="$(mktemp "${TMPDIR:-/tmp}/foreign-review-send.XXXXXX")" || exit 4
BODY_FILE="$(mktemp "${TMPDIR:-/tmp}/foreign-review-body.XXXXXX")" || exit 4
LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/foreign-review-log.XXXXXX")"  || exit 4
HTTP_OUT="$(mktemp "${TMPDIR:-/tmp}/foreign-review-http.XXXXXX")" || exit 4
HTTP_CODE_FILE="$(mktemp "${TMPDIR:-/tmp}/foreign-review-code.XXXXXX")" || exit 4

if [ -n "$OUT_FILE" ]; then
  RAW_FILE="$OUT_FILE.raw"
else
  RAW_FILE="$(mktemp "${TMPDIR:-/tmp}/foreign-review-raw.XXXXXX")" || exit 4
fi

CURRENT_CHILD=""
cleanup() {
  # Kill any in-flight backend process group, drop working temps. The raw file
  # is preserved whenever it has content (the inspection contract); an empty
  # partial is litter and is removed.
  if [ -n "$CURRENT_CHILD" ]; then
    kill -TERM -- "-$CURRENT_CHILD" 2>/dev/null || kill -TERM "$CURRENT_CHILD" 2>/dev/null
    kill -KILL -- "-$CURRENT_CHILD" 2>/dev/null
  fi
  rm -f "$SEND_FILE" "$BODY_FILE" "$LOG_FILE" "$HTTP_OUT" "$HTTP_CODE_FILE"
  if [ -n "${RAW_FILE:-}" ] && [ -f "$RAW_FILE" ] && [ ! -s "$RAW_FILE" ]; then
    rm -f "$RAW_FILE"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- assemble the stdin payload: [prompt] + pack -----------------------------
if [ -n "$PROMPT_FILE" ]; then
  cat "$PROMPT_FILE" > "$SEND_FILE"
  printf '\n' >> "$SEND_FILE"
else
  case "$MODE" in
    plan) printf 'You are an external plan reviewer. Review the plan pack below and respond ONLY with JSON conforming to the provided schema.\n\n' > "$SEND_FILE" ;;
    code) printf 'You are an external code reviewer. Review the review pack below and respond ONLY with JSON conforming to the provided schema.\n\n' > "$SEND_FILE" ;;
  esac
fi
cat "$INPUT" >> "$SEND_FILE"

# --- backend runners ---------------------------------------------------------
# Codex: repo-root cwd + --skip-git-repo-check (codex refuses untrusted non-git
# cwds), pack on STDIN (codex exec reads instructions from stdin when no PROMPT
# argument is given), final message captured via -o. Never the pack on argv.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
run_codex() {
  (
    cd "$REPO_ROOT" || exit 4
    exec "$CODEX_BIN" exec -s read-only --skip-git-repo-check \
      --output-schema "$SCHEMA_ABS" --color never \
      -o "$RAW_FILE" < "$SEND_FILE" >> "$LOG_FILE" 2>&1
  )
}

build_openrouter_body() {
  # stream:true is what makes idle detection possible at all — a non-streaming
  # call yields nothing until it finishes, so a slow-but-healthy generation and
  # a hang are indistinguishable and a timeout loses the entire response.
  # max_tokens bounds the generation; reasoning is disabled because reasoning
  # tokens are billable, invisible in the answer, and (before the content-aware
  # watchdog below) used to look like liveness.
  jq -n --rawfile content "$SEND_FILE" --slurpfile schema "$SCHEMA_ABS" \
        --arg model "$MODEL" --argjson max_tokens "$MAX_TOKENS" '
    { model: $model,
      temperature: 0.2,
      stream: true,
      max_tokens: $max_tokens,
      reasoning: { enabled: false },
      response_format: {
        type: "json_schema",
        json_schema: { name: "review_findings", strict: true, schema: $schema[0] }
      },
      messages: [ { role: "user", content: $content } ] }' > "$BODY_FILE" \
  || { err "failed to build request body (is $SCHEMA_ABS valid JSON?)"; return 1; }
}

# --- SSE readers -------------------------------------------------------------
# All three tolerate a truncated trailing line (`fromjson?` drops it), because
# they are called against a file curl is still writing to.

# Accumulated ASSISTANT CONTENT. Deliberately NOT the raw byte count: OpenRouter
# pads upstream stalls with `: OPENROUTER PROCESSING` comment frames, which are
# wire bytes. Measuring liveness on the wire would keep a stalled request alive
# until the wall clock — the exact hang this is built to catch.
sse_content() {
  sed -n 's/^data: //p' "$1" 2>/dev/null \
    | jq -j -R 'select(. != "[DONE]") | fromjson? | .choices[0].delta.content // empty' 2>/dev/null
}

sse_finish_reason() {
  sed -n 's/^data: //p' "$1" 2>/dev/null \
    | jq -r -R 'select(. != "[DONE]") | fromjson? | .choices[0].finish_reason // empty' 2>/dev/null \
    | grep -v '^$' | tail -n 1
}

sse_error() {
  sed -n 's/^data: //p' "$1" 2>/dev/null \
    | jq -r -R 'select(. != "[DONE]") | fromjson? | .error.message // empty' 2>/dev/null \
    | grep -v '^$' | head -n 1
}

run_openrouter() {
  # -N disables curl's output buffering. Without it the file grows in kilobyte
  # steps and a healthy generation can look idle between flushes.
  "$CURL_CMD" -sS -N -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $OR_KEY" \
    -H "Content-Type: application/json" \
    --data @"$BODY_FILE" \
    -o "$HTTP_OUT" -w '%{http_code}' > "$HTTP_CODE_FILE" 2>> "$LOG_FILE"
}

kill_child_group() {
  kill -TERM -- "-$CURRENT_CHILD" 2>/dev/null || kill -TERM "$CURRENT_CHILD" 2>/dev/null
  wd_grace=0
  while kill -0 "$CURRENT_CHILD" 2>/dev/null && [ "$wd_grace" -lt 2 ]; do
    sleep 1; wd_grace=$((wd_grace + 1))
  done
  kill -KILL -- "-$CURRENT_CHILD" 2>/dev/null || kill -KILL "$CURRENT_CHILD" 2>/dev/null
  wait "$CURRENT_CHILD" 2>/dev/null
  CURRENT_CHILD=""
}

# Content-aware watchdog, openrouter only. `run_with_watchdog` is left untouched
# for codex — it is the best-tested path and is generic across backends.
# Returns 124 on wall-clock expiry, 125 on content-idle expiry (two conditions
# curl itself reports as the same exit 28, which is why this is not curl's job).
run_openrouter_watchdog() {
  set -m
  run_openrouter &
  CURRENT_CHILD=$!
  set +m
  wd_waited=0; wd_idle=0; wd_last_len=0
  while kill -0 "$CURRENT_CHILD" 2>/dev/null; do
    sleep 1
    wd_waited=$((wd_waited + 1))
    wd_len="$(sse_content "$HTTP_OUT" | wc -c | tr -d ' ')"
    case "$wd_len" in ''|*[!0-9]*) wd_len="$wd_last_len" ;; esac
    if [ "$wd_len" -gt "$wd_last_len" ]; then
      wd_last_len="$wd_len"; wd_idle=0
    else
      wd_idle=$((wd_idle + 1))
    fi
    if [ "$wd_idle" -ge "$IDLE_TIMEOUT" ]; then
      kill_child_group
      return 125
    fi
    if [ "$wd_waited" -ge "$TIMEOUT" ]; then
      kill_child_group
      return 124
    fi
  done
  wait "$CURRENT_CHILD"
  wd_rc=$?
  CURRENT_CHILD=""
  return $wd_rc
}

# --- portable watchdog (no timeout(1) on macOS) ------------------------------
# Runs "$@" in the background in its OWN process group (set -m), polls, and on
# expiry TERMs then KILLs the whole group. Returns 124 on timeout, else the
# command's exit status.
run_with_watchdog() {
  set -m
  "$@" &
  CURRENT_CHILD=$!
  set +m
  wd_waited=0
  while kill -0 "$CURRENT_CHILD" 2>/dev/null; do
    if [ "$wd_waited" -ge "$TIMEOUT" ]; then
      kill -TERM -- "-$CURRENT_CHILD" 2>/dev/null || kill -TERM "$CURRENT_CHILD" 2>/dev/null
      wd_grace=0
      while kill -0 "$CURRENT_CHILD" 2>/dev/null && [ "$wd_grace" -lt 2 ]; do
        sleep 1; wd_grace=$((wd_grace + 1))
      done
      # KILL the whole GROUP unconditionally: the leader dying on TERM must not
      # spare a TERM-ignoring descendant still in the group.
      kill -KILL -- "-$CURRENT_CHILD" 2>/dev/null || kill -KILL "$CURRENT_CHILD" 2>/dev/null
      wait "$CURRENT_CHILD" 2>/dev/null
      CURRENT_CHILD=""
      return 124
    fi
    sleep 1
    wd_waited=$((wd_waited + 1))
  done
  wait "$CURRENT_CHILD"
  wd_rc=$?
  CURRENT_CHILD=""
  return $wd_rc
}

# transport_failure <rc> — retry-once class: curl transport exits, or codex
# stream disconnects (observed eating a 119k-token run live).
transport_failure() {
  case "$BACKEND" in
    openrouter) case "$1" in 18|52|56) return 0 ;; esac ;;
    codex)      grep -qi 'stream.*disconnect' "$LOG_FILE" 2>/dev/null && return 0 ;;
  esac
  return 1
}

# --- run (retry ONCE on transport-class failure, then loud exit 4) -----------
if [ "$BACKEND" = "openrouter" ]; then
  build_openrouter_body || exit 4
fi

attempt=1
while :; do
  : > "$RAW_FILE"
  : > "$LOG_FILE"
  case "$BACKEND" in
    codex)      run_with_watchdog run_codex ;;
    openrouter) run_openrouter_watchdog ;;
  esac
  rc=$?
  [ $rc -eq 0 ] && break
  if [ $rc -eq 124 ]; then
    # Wall clock. NOT retried: the request was progressing, so a retry re-bills
    # the whole input and is likely to expire the same way.
    err "backend call failed: $BACKEND_ARG timed out after ${TIMEOUT}s (process group killed)"
    [ -s "$RAW_FILE" ] && err "partial raw output preserved at $RAW_FILE"
    [ -s "$HTTP_OUT" ] && err "partial stream preserved at $HTTP_OUT"
    exit 4
  fi
  if [ $rc -eq 125 ]; then
    # Content-idle. A distinguishable condition with its own message: the stream
    # was open but produced no assistant content for the idle window, which is a
    # stalled provider rather than a slow one.
    err "backend call failed: $BACKEND_ARG produced no content for ${IDLE_TIMEOUT}s (stalled; process group killed after ${wd_waited:-?}s)"
    [ -s "$HTTP_OUT" ] && err "partial stream preserved at $HTTP_OUT"
    exit 4
  fi
  if [ "$attempt" -eq 1 ] && transport_failure "$rc"; then
    note "transport-class failure (exit $rc) — retrying once"
    attempt=2
    continue
  fi
  err "backend call failed: $BACKEND_ARG exited $rc"
  if [ -s "$LOG_FILE" ]; then
    err "last backend output:"
    tail -n 5 "$LOG_FILE" | sed 's/^/foreign-review:   /' >&2
  fi
  [ -s "$RAW_FILE" ] && err "raw output preserved at $RAW_FILE"
  exit 4
done

# --- openrouter: unwrap the completion envelope into RAW_FILE ----------------
if [ "$BACKEND" = "openrouter" ]; then
  http_code="$(cat "$HTTP_CODE_FILE" 2>/dev/null)"
  if [ "$http_code" != "200" ]; then
    err "backend call failed: openrouter returned HTTP ${http_code:-<none>}"
    if [ -s "$HTTP_OUT" ]; then
      err "response body (first lines):"
      head -c 500 "$HTTP_OUT" | sed 's/^/foreign-review:   /' >&2
      printf '\n' >&2
    fi
    exit 4
  fi
  # An error can arrive INSIDE a 200 stream — check before trusting content.
  stream_err="$(sse_error "$HTTP_OUT")"
  if [ -n "$stream_err" ]; then
    err "backend call failed: openrouter reported an error mid-stream: $stream_err"
    exit 4
  fi

  sse_content "$HTTP_OUT" > "$RAW_FILE" 2>> "$LOG_FILE"
  if [ ! -s "$RAW_FILE" ]; then
    err "backend call failed: no assistant content in openrouter stream"
    err "stream preserved for inspection:"
    head -c 500 "$HTTP_OUT" | sed 's/^/foreign-review:   /' >&2
    printf '\n' >&2
    exit 4
  fi

  # Completeness gate. Without this, a stream cut short yields a truncated JSON
  # string and `JSON.parse` becomes the truncation detector — which reports a
  # confusing schema error instead of the real cause, and (worse) could accept a
  # partial finding set that merely happens to close.
  if ! grep -q '^data: \[DONE\]' "$HTTP_OUT" 2>/dev/null; then
    err "backend call failed: stream ended without [DONE] — response is TRUNCATED, not merely invalid"
    err "partial content preserved at $RAW_FILE (NOT written to --out)"
    exit 4
  fi

  finish="$(sse_finish_reason "$HTTP_OUT")"
  case "$finish" in
    stop|'') : ;;
    length)
      err "backend call failed: output capped at max_tokens ($MAX_TOKENS) — findings are incomplete"
      err "re-run with a larger --max-tokens, or narrow the review scope"
      err "partial content preserved at $RAW_FILE (NOT written to --out)"
      exit 4 ;;
    *)
      err "backend call failed: unexpected finish_reason '$finish'"
      exit 4 ;;
  esac
fi

if [ ! -s "$RAW_FILE" ]; then
  err "backend call failed: $BACKEND_ARG produced no output"
  exit 4
fi

# --- validate (real validator, never jq); --out only after it passes ---------
if ! validator_out="$("$NODE_BIN" "$VALIDATOR" "$SCHEMA_ABS" "$RAW_FILE" 2>&1)"; then
  err "backend output FAILED schema validation — raw preserved at $RAW_FILE"
  printf '%s\n' "$validator_out" | sed 's/^/foreign-review:   /' >&2
  err "--out was NOT written."
  exit 5
fi

if [ -n "$OUT_FILE" ]; then
  cp "$RAW_FILE" "$OUT_FILE" || { err "could not write $OUT_FILE"; exit 4; }
  note "valid review written to $OUT_FILE (raw at $RAW_FILE)"
else
  cat "$RAW_FILE"
  note "raw preserved at $RAW_FILE"
fi
exit 0
