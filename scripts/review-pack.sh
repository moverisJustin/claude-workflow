#!/usr/bin/env bash
# review-pack.sh — assemble a full REVIEW PACK for an external (foreign-model)
# PR review: memory context first, then the spec under review, then the
# branch's changed files inlined in full up to a byte budget, then unified
# diff hunks for whatever could not be inlined.
#
# The pack is what a backend-agnostic reviewer (Codex, Kimi via OpenRouter)
# receives as its entire view of the task, so it must carry:
#   1. The memory context pack (via memory-context.sh) — its injection-boundary
#      header stays at the very top. The learned-patterns slice is scoped with
#      --grep derived from changed-file basenames (fallback: plain run).
#   2. "## Spec under review" — resolved in order: --spec FILE, else the path
#      on the '- **BSpec**:' ledger line of .claude/task-context.md (only if
#      it points to an existing file), else the '## Objective' + '## Plan'
#      sections of task-context.md, else a loud
#      'SPEC: none found — spec-drift review degraded' marker.
#   3. "## Changed files (full)" — git diff --name-only <base>...HEAD, each
#      existing text file inlined with '=== FILE: path ===' headers and line
#      numbers, until --budget bytes (default 400000) minus a 20% output
#      headroom reserve is reached.
#   4. "## Diff hunks (files not inlined above)" — unified diffs ONLY for
#      files that were NOT fully inlined (no duplication); binary files are
#      listed by name only.
# Overflow is loud: 'TRUNCATED: <n> files as hunks, <m> files omitted' in the
# pack AND on stderr.
#
# Usage:
#   review-pack.sh <base-branch> [--spec FILE] [--budget BYTES] [--root DIR]
#                  [--exclude GLOB]... [--out FILE] [--quiet]
#     <base-branch>   base ref to diff against (BASE...HEAD)
#     --spec FILE     explicit spec document (skips ledger/task-context lookup)
#     --budget BYTES  total pack byte budget (default 400000); 20% is reserved
#                     as headroom for model output
#     --root DIR      repo root to operate in (default: $PWD)
#     --exclude GLOB  omit matching paths from the pack entirely (repeatable).
#                     This is the mechanism review-backends.json's `exclude`
#                     array feeds; without it the secret scrub in
#                     foreign-review.sh is the only backstop, and a scrub is a
#                     HARD STOP — one secret-shaped fixture makes the entire
#                     review impossible instead of just trimming the pack.
#     --out FILE      write the pack to FILE instead of stdout
#     --quiet         suppress informational notes on stderr (errors and
#                     truncation warnings always print)
#
# Test seam: MEMORY_CONTEXT_SH overrides the memory-context.sh location
# (default resolution: <root>/.claude/scripts/memory-context.sh, else
# ~/.claude/scripts/memory-context.sh) — matching the LEARNED_PATTERNS_FILE
# convention in memory-context.sh.
#
# bash 3.2 + awk only. Always exits 0 (memory-context.sh convention) except
# for usage errors (exit 2), so callers can run it unconditionally. When the
# repo or base ref is invalid, NOTHING is written and a loud stderr note says
# why — a broken pack is never silently substituted for a real one.

set -u

usage() {
  cat >&2 <<'EOF'
Usage: review-pack.sh <base-branch> [--spec FILE] [--budget BYTES] [--root DIR]
                      [--exclude GLOB]... [--out FILE] [--quiet]
  Assemble a review pack (memory context + spec + changed files + diff hunks)
  for an external PR reviewer.
    <base-branch>   base ref to diff against (BASE...HEAD)
    --spec FILE     explicit spec document to include
    --budget BYTES  total byte budget (default 400000; 20% output headroom reserved)
    --root DIR      repo root (default: $PWD)
    --out FILE      write the pack to FILE instead of stdout
    --exclude GLOB  omit matching paths from the pack (repeatable); use for
                    secret-bearing or fixture files that must never be sent
    --quiet         suppress informational notes (errors always print)
EOF
}

ROOT="$PWD"
BASE=""
SPEC_ARG=""
BUDGET=400000
OUT_FILE=""
EXCLUDES=""
DROPPED_LIST=""
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --spec)
      [ $# -ge 2 ] || { echo "review-pack: --spec needs a FILE" >&2; exit 2; }
      SPEC_ARG="$2"; shift 2 ;;
    --budget)
      [ $# -ge 2 ] || { echo "review-pack: --budget needs BYTES" >&2; exit 2; }
      BUDGET="$2"; shift 2 ;;
    --root)
      [ $# -ge 2 ] || { echo "review-pack: --root needs a DIR" >&2; exit 2; }
      ROOT="$2"; shift 2 ;;
    --out)
      [ $# -ge 2 ] || { echo "review-pack: --out needs a FILE" >&2; exit 2; }
      OUT_FILE="$2"; shift 2 ;;
    --exclude)
      [ $# -ge 2 ] || { echo "review-pack: --exclude needs a GLOB" >&2; exit 2; }
      EXCLUDES="$EXCLUDES$2
"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "review-pack: unknown arg: $1" >&2; usage; exit 2 ;;
    *)
      if [ -z "$BASE" ]; then BASE="$1"; shift
      else echo "review-pack: unexpected extra argument: $1" >&2; usage; exit 2
      fi ;;
  esac
done

[ -n "$BASE" ] || { echo "review-pack: base branch is required" >&2; usage; exit 2; }
case "$BUDGET" in
  ''|*[!0-9]*) echo "review-pack: --budget must be a positive integer (got: $BUDGET)" >&2; exit 2 ;;
esac
[ "$BUDGET" -gt 0 ] || { echo "review-pack: --budget must be > 0" >&2; exit 2; }

# note: informational (silenced by --quiet). loud: always prints (errors,
# degraded modes, truncation) — fail-loud, never fail-silent.
note() { [ "$QUIET" -eq 0 ] && printf 'review-pack: %s\n' "$1" >&2; return 0; }
loud() { printf 'review-pack: %s\n' "$1" >&2; }

GIT() { git -C "$ROOT" -c core.quotePath=false "$@"; }

# --- validity gates: nothing is written when the repo/base is invalid --------
if ! GIT rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  loud "not a git repository: $ROOT — nothing written"
  exit 0
fi
if ! GIT rev-parse --verify --quiet "$BASE^{commit}" >/dev/null 2>&1; then
  loud "unknown base ref '$BASE' in $ROOT — nothing written"
  exit 0
fi
if ! CHANGED="$(GIT diff --no-renames --name-only "$BASE...HEAD" 2>/dev/null)"; then
  loud "cannot diff $BASE...HEAD in $ROOT (unrelated histories?) — nothing written"
  exit 0
fi

# --- exclusions ---------------------------------------------------------------
# Drop paths matching any --exclude glob BEFORE they can reach a third party.
# review-backends.json has shipped an `exclude` array (.env*, **/*.pem,
# **/secrets/**) since it was written and cross-review/SKILL.md instructs callers
# to "pass the config's exclude globs through" — but nothing consumed them, so
# the list was dead config and the secret scrub was the only backstop. A scrub is
# a HARD STOP, not an exclusion: one matching file made the whole review
# impossible rather than merely trimming the pack.
# Config-sourced excludes. review-backends.json has always carried an `exclude`
# array and nothing read it, so the protection existed only if an operator
# retyped the same globs on the command line — the exact unenforced-instruction
# pattern this repo keeps getting bitten by. Resolution order matches the
# cross-review skill: project, then user, then the shipped default.
for _cfg in "$ROOT/.claude/review-backends.json" \
            "$HOME/.claude/review-backends.json" \
            "$HOME/.claude/skills/cross-review/review-backends.json"; do
  [ -f "$_cfg" ] || continue
  _from_cfg="$(python3 -c '
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
for g in (d.get("exclude") or []):
    if isinstance(g,str) and g.strip(): print(g)
' "$_cfg" 2>/dev/null)"
  if [ -n "$_from_cfg" ]; then
    EXCLUDES="$EXCLUDES$_from_cfg
"
    note "applied $(printf '%s\n' "$_from_cfg" | grep -c .) exclude glob(s) from $_cfg"
  fi
  break
done

if [ -n "$EXCLUDES" ]; then
  KEPT=""
  DROPPED=0
  OLDIFS="$IFS"
  IFS='
'
  # set -f is load-bearing: `for g in $EXCLUDES` is unquoted so the shell applies
  # PATHNAME EXPANSION to the globs themselves before they are ever used as
  # patterns. A literal '*' expanded to the CWD file list and matched nothing;
  # '.env*' only worked by luck, because nothing in CWD matched it.
  set -f
  for f in $CHANGED; do
    skip=0
    for g in $EXCLUDES; do
      # shellcheck disable=SC2254 — $g is a glob on purpose
      case "$f" in
        $g) skip=1; break ;;
      esac
      # `**/x` should also match `x` at the repo root.
      case "$g" in
        '**/'*) case "$f" in ${g#**/}) skip=1; break ;; esac ;;
      esac
    done
    if [ "$skip" -eq 1 ]; then
      DROPPED=$((DROPPED + 1))
      DROPPED_LIST="$DROPPED_LIST$f
"
    else
      KEPT="$KEPT$f
"
    fi
  done
  set +f
  IFS="$OLDIFS"
  CHANGED="$(printf '%s' "$KEPT")"
  # Everything filtered out is NOT the same as an empty branch. Without this the
  # pack reads as "no changed files" and a reviewer concludes the diff is empty.
  if [ -z "$CHANGED" ] && [ "$DROPPED" -gt 0 ]; then
    loud "EXCLUDED: all $DROPPED changed file(s) were excluded — pack has NO diff content"
  fi
  [ "$DROPPED" -gt 0 ] && loud "excluded $DROPPED file(s) from the pack per --exclude"
fi

EFFECTIVE=$((BUDGET - BUDGET / 5)) # reserve 20% headroom for model output

TMP="$(mktemp "${TMPDIR:-/tmp}/revpack.XXXXXX")" || exit 1
CHUNK="$(mktemp "${TMPDIR:-/tmp}/revpack-chunk.XXXXXX")" || exit 1
MEMOUT="$(mktemp "${TMPDIR:-/tmp}/revpack-mem.XXXXXX")" || exit 1
DEMOLIST="$(mktemp "${TMPDIR:-/tmp}/revpack-demo.XXXXXX")" || exit 1
DELLIST="$(mktemp "${TMPDIR:-/tmp}/revpack-del.XXXXXX")" || exit 1
BINLIST="$(mktemp "${TMPDIR:-/tmp}/revpack-bin.XXXXXX")" || exit 1
trap 'rm -f "$TMP" "$CHUNK" "$MEMOUT" "$DEMOLIST" "$DELLIST" "$BINLIST"' EXIT

# fits <file> — true if appending <file> keeps the pack within EFFECTIVE bytes.
fits() {
  local cur sz
  cur=$(wc -c < "$TMP")
  sz=$(wc -c < "$1")
  [ $((cur + sz)) -le "$EFFECTIVE" ]
}

# --- 1. memory context pack (injection-boundary header stays at top) ---------
MC=""
if [ -n "${MEMORY_CONTEXT_SH:-}" ]; then
  if [ -f "$MEMORY_CONTEXT_SH" ]; then MC="$MEMORY_CONTEXT_SH"
  else loud "MEMORY_CONTEXT_SH points at a missing file: $MEMORY_CONTEXT_SH"
  fi
elif [ -f "$ROOT/.claude/scripts/memory-context.sh" ]; then
  MC="$ROOT/.claude/scripts/memory-context.sh"
elif [ -f "$HOME/.claude/scripts/memory-context.sh" ]; then
  MC="$HOME/.claude/scripts/memory-context.sh"
fi

if [ -n "$MC" ]; then
  # --grep pattern from changed-file basenames (extension stripped; regex
  # metacharacters neutralized to '.' which matches themselves and more).
  GREP_PAT=""
  if [ -n "$CHANGED" ]; then
    GREP_PAT="$(printf '%s\n' "$CHANGED" | awk -F/ '
      { b = $NF; sub(/\.[^.]*$/, "", b); gsub(/[^A-Za-z0-9_-]/, ".", b); if (b != "") print b }
    ' | sort -u | paste -sd'|' -)"
  fi
  if [ -n "$GREP_PAT" ]; then
    bash "$MC" --root "$ROOT" --grep "$GREP_PAT" --quiet > "$MEMOUT" 2>/dev/null
  fi
  if [ ! -s "$MEMOUT" ]; then # fallback: plain run
    bash "$MC" --root "$ROOT" --quiet > "$MEMOUT" 2>/dev/null
  fi
  if [ -s "$MEMOUT" ]; then
    cat "$MEMOUT" >> "$TMP"
    printf '\n' >> "$TMP"
  else
    loud "no memory found under $ROOT — pack carries no memory section"
  fi
else
  loud "memory-context.sh not found ($ROOT/.claude/scripts or ~/.claude/scripts) — pack carries no memory section"
fi

# --- 2. spec under review ----------------------------------------------------
TASKCTX="$ROOT/.claude/task-context.md"
SPEC_PATH=""
SPEC_SRC=""
TASKCTX_SECTIONS=""

if [ -n "$SPEC_ARG" ]; then
  if [ -f "$SPEC_ARG" ]; then
    SPEC_PATH="$SPEC_ARG"; SPEC_SRC="--spec argument"
  else
    # An explicit --spec that is wrong must not silently cascade to fallbacks.
    loud "--spec file not found: $SPEC_ARG — spec section degraded to 'none found'"
  fi
else
  if [ -f "$TASKCTX" ]; then
    # 2b. '- **BSpec**:' ledger line — first token, only if it is a real file.
    # First whitespace-delimited token, extracted in awk — never word-split or
    # glob-expanded by the shell (a ledger value of '*' must not match cwd files).
    tok="$(awk '
      /^```/ { fence = !fence; next }
      !fence && /^- \*\*BSpec\*\*:/ { sub(/^- \*\*BSpec\*\*:[ \t]*/, ""); print $1; exit }
    ' "$TASKCTX")"
    if [ -n "$tok" ]; then
      case "$tok" in
        /*) [ -f "$tok" ] && { SPEC_PATH="$tok"; SPEC_SRC="BSpec ledger ($tok)"; } ;;
        *)  [ -f "$ROOT/$tok" ] && { SPEC_PATH="$ROOT/$tok"; SPEC_SRC="BSpec ledger ($tok)"; } ;;
      esac
    fi
    # 2c. '## Objective' + '## Plan' sections of task-context.md (fence-aware).
    if [ -z "$SPEC_PATH" ]; then
      TASKCTX_SECTIONS="$(awk '
        /^```/ { fence = !fence }
        !fence && /^## / { keep = ($0 ~ /^## Objective[ \t]*$/ || $0 ~ /^## Plan[ \t]*$/) }
        keep { print }
      ' "$TASKCTX")"
    fi
  fi
fi

printf '\n## Spec under review\n' >> "$TMP"
if [ -n "$SPEC_PATH" ]; then
  {
    printf '_source: %s_\n\n' "$SPEC_SRC"
    cat "$SPEC_PATH"
    printf '\n'
  } >> "$TMP"
elif [ -n "$TASKCTX_SECTIONS" ]; then
  {
    printf '_source: %s — Objective + Plan sections (no BSpec doc resolved)_\n\n' "$TASKCTX"
    printf '%s\n' "$TASKCTX_SECTIONS"
  } >> "$TMP"
else
  printf '\nSPEC: none found — spec-drift review degraded\n' >> "$TMP"
  loud "SPEC: none found — spec-drift review degraded"
fi

# --- 3. changed files, inlined in full up to the budget ----------------------
# Binary detection via numstat: binary files report '-<TAB>-<TAB>path'.
BINARIES="$(GIT diff --no-renames --numstat "$BASE...HEAD" 2>/dev/null | awk -F'\t' '$1 == "-" && $2 == "-" { print $3 }')"
is_binary() { [ -n "$BINARIES" ] && printf '%s\n' "$BINARIES" | grep -qxF "$1"; }

# DECLARE the exclusions in the pack, not just on stderr. A reviewer that cannot
# see what was withheld reports the withheld thing as missing — this exact
# blindness produced false "no test coverage anywhere in the pack" findings in
# two consecutive reviews, because the test file had been excluded. Same
# loud-marker convention as SPEC: and TRUNCATED:.
if [ "${DROPPED:-0}" -gt 0 ]; then
  {
    printf '\nEXCLUDED: %s file(s) withheld from this pack by --exclude.\n' "$DROPPED"
    printf 'These files ARE part of the change under review. Their absence is NOT\n'
    printf 'evidence of missing code, tests, or coverage — do not report it as such:\n'
    printf '%s' "$DROPPED_LIST" | sed 's/^/  - /'
    printf '\n'
  } >> "$TMP"
  loud "EXCLUDED: $DROPPED file(s) declared in the pack"
fi

printf '\n## Changed files (full)\n\n' >> "$TMP"
inlined=0
budget_hit=0
if [ -n "$CHANGED" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if is_binary "$f"; then
      echo "$f" >> "$BINLIST"; continue
    fi
    if [ ! -f "$ROOT/$f" ]; then # deleted (or otherwise absent): hunks section
      echo "$f" >> "$DELLIST"; continue
    fi
    if [ "$budget_hit" -eq 1 ]; then
      echo "$f" >> "$DEMOLIST"; continue
    fi
    {
      printf '=== FILE: %s ===\n' "$f"
      awk '{ printf "%6d\t%s\n", NR, $0 }' "$ROOT/$f"
      printf '\n'
    } > "$CHUNK"
    if fits "$CHUNK"; then
      cat "$CHUNK" >> "$TMP"
      inlined=$((inlined + 1))
    else
      budget_hit=1
      echo "$f" >> "$DEMOLIST"
    fi
  done <<EOF
$CHANGED
EOF
fi
if [ "$inlined" -eq 0 ]; then
  if [ -z "$CHANGED" ]; then
    printf '(no changed files between %s and HEAD)\n' "$BASE" >> "$TMP"
    note "no changed files between $BASE and HEAD"
  else
    printf '(none inlined)\n' >> "$TMP"
  fi
fi

# --- 4. diff hunks ONLY for files not inlined above (no duplication) ---------
printf '\n## Diff hunks (files not inlined above)\n\n' >> "$TMP"
hunks_emitted=0
demoted_as_hunks=0
omitted=0

# emit_hunk <path> — returns 0 if the diff was appended, 1 if omitted.
emit_hunk() {
  GIT diff --no-renames "$BASE...HEAD" -- "$1" > "$CHUNK" 2>/dev/null
  printf '\n' >> "$CHUNK"
  if fits "$CHUNK"; then
    cat "$CHUNK" >> "$TMP"
    hunks_emitted=$((hunks_emitted + 1))
    return 0
  fi
  return 1
}

if [ -s "$DEMOLIST" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if emit_hunk "$f"; then demoted_as_hunks=$((demoted_as_hunks + 1))
    else omitted=$((omitted + 1))
    fi
  done < "$DEMOLIST"
fi
if [ -s "$DELLIST" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    emit_hunk "$f" || omitted=$((omitted + 1))
  done < "$DELLIST"
fi
if [ -s "$BINLIST" ]; then
  printf 'Binary files (listed by name only):\n' >> "$TMP"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf -- '- %s (binary)\n' "$f" >> "$TMP"
  done < "$BINLIST"
  printf '\n' >> "$TMP"
fi
if [ "$hunks_emitted" -eq 0 ] && [ ! -s "$BINLIST" ]; then
  printf '(none — all changed files inlined in full above)\n' >> "$TMP"
fi

# --- overflow marker: in the pack AND on stderr ------------------------------
if [ $((demoted_as_hunks + omitted)) -gt 0 ]; then
  printf '\nTRUNCATED: %d files as hunks, %d files omitted\n' "$demoted_as_hunks" "$omitted" >> "$TMP"
  loud "TRUNCATED: $demoted_as_hunks files as hunks, $omitted files omitted (budget ${BUDGET}B, ${EFFECTIVE}B after headroom)"
fi

# --- route: --out suppresses stdout ------------------------------------------
if [ -n "$OUT_FILE" ]; then
  if cp "$TMP" "$OUT_FILE"; then
    note "pack written to $OUT_FILE ($(wc -c < "$TMP" | tr -d ' ') bytes)"
  else
    loud "could not write $OUT_FILE"
  fi
else
  cat "$TMP"
fi

exit 0
