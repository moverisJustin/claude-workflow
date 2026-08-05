#!/usr/bin/env bash
# reindex-lessons.sh — regenerate the deferred-corpus heading index inside the
# always-on rules file.
#
# Boris v3.1 splits Learned Patterns in two:
#   ~/.claude/rules/learned-patterns.md    always-on: hot core + THIS index
#   ~/.claude/lessons/learned-patterns.md  deferred corpus, retrieved on demand
#
# The index is the map that keeps deferred lessons discoverable, so it must track
# the corpus. Run after appending a lesson, and from install.sh / sync-lessons.sh.
#
# Idempotent: rewrites everything below the index marker, leaves the hot core alone.
# Fence-aware, because a corpus lesson body can contain a column-0 '## ' inside a
# fenced block (see the markdown-splitter lesson).
set -euo pipefail

CORPUS="${CORPUS_FILE:-$HOME/.claude/lessons/learned-patterns.md}"
RULES="${RULES_FILE:-$HOME/.claude/rules/learned-patterns.md}"
MARKER='## Deferred corpus — heading index'

[ -f "$RULES" ] || { echo "reindex-lessons: no rules file at $RULES" >&2; exit 1; }
if [ ! -f "$CORPUS" ]; then
  echo "reindex-lessons: no corpus at $CORPUS — nothing to index" >&2
  exit 0
fi
grep -qF "$MARKER" "$RULES" || {
  echo "reindex-lessons: marker not found in $RULES — refusing to guess" >&2
  exit 1
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Everything up to and including the marker line survives untouched.
awk -v m="$MARKER" '{ print } index($0, m) { exit }' "$RULES" > "$TMP"

{
  printf '\n'
  printf "Retrieve with \`memory-context.sh --grep '<keyword>'\`. Full text:\n"
  printf '`%s`.\n' "$CORPUS"
} >> "$TMP"

awk '
  /^```/            { fence = !fence; next }
  !fence && /^## /  { printf "\n**%s**\n", substr($0, 4); next }
  !fence && /^### / {
      h = substr($0, 5)
      if (length(h) > 96) h = substr(h, 1, 93) "..."
      printf "- %s\n", h
  }
' "$CORPUS" >> "$TMP"

mv "$TMP" "$RULES"
trap - EXIT

n=$(awk '/^```/{f=!f;next} !f && /^### /{c++} END{print c+0}' "$CORPUS")
echo "reindex-lessons: indexed $n deferred lessons into $(basename "$RULES")"
