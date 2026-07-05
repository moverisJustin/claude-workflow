#!/usr/bin/env bash
# Hook: PreToolUse (Bash)
# Safety net for destructive commands that native /rewind cannot undo
# (bash-driven file and git-history destruction).
#
# Contract: receives the hook payload as JSON on stdin (tool_name,
# tool_input.command, ...). Parses with python3 — jq is optional on target
# machines, and a jq-dependent guard would silently no-op exactly where it
# matters. Fail-open by design: any parse/git error allows the command.
#
# Behavior:
#   - git-destructive commands (reset --hard, clean -f, checkout ., restore .,
#     push --force): create a NON-MUTATING checkpoint (tag HEAD + `git stash
#     create`, with the stash commit preserved via a tag so `git stash list`
#     stays clean and a later `git stash pop` never restores our snapshot),
#     then exit silently so the normal permission flow still applies.
#     Escalate to an "ask" prompt only if no checkpoint could be created
#     inside a repo.
#   - rm -rf: checkpoint what git can see, then "ask" ONLY for high-risk
#     targets (absolute paths outside temp dirs, ~, $HOME, .., bare * or .).
#     Untracked files deleted by rm are unrecoverable via /rewind or git, so
#     those get a human gate even in auto-accept modes; routine relative-path
#     and temp-dir cleanup stays silent.
#   - auto-checkpoint/* tags older than 7 days are pruned on each firing.
#
# Recovery:  git tag -l 'auto-checkpoint/*'
#            git reset --hard auto-checkpoint/<ts>        (committed state)
#            git stash apply auto-checkpoint/<ts>-work    (uncommitted state)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="$PROJECT_DIR/.claude/project-config.json"
AUDIT_DIR="$PROJECT_DIR/.claude/audit"
PRUNE_DAYS=7

PAYLOAD=$(cat 2>/dev/null || true)
[ -z "$PAYLOAD" ] && exit 0

command -v python3 >/dev/null 2>&1 || exit 0

COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""), end="")
except Exception:
    pass
' 2>/dev/null) || COMMAND=""
[ -z "$COMMAND" ] && exit 0

# Respect per-project opt-out: skip git guards when git is disabled
if [ -f "$CONFIG_FILE" ]; then
  GIT_ENABLED=$(python3 -c "import json; print(str(json.load(open('$CONFIG_FILE')).get('git_enabled', True)).lower())" 2>/dev/null || echo "true")
  [ "$GIT_ENABLED" = "false" ] && exit 0
fi

# Classify the command. Regex search over the WHOLE string so compound
# commands (`cd x && git reset --hard`) are caught, unlike a prefix match.
# A false positive (pattern inside a quoted string) costs one checkpoint
# or one extra prompt — acceptable for a guard.
# Output: "<CATEGORY>\t<pattern>\t<detail>"
MATCH=$(printf '%s' "$COMMAND" | python3 -c '
import re, shlex, sys

cmd = sys.stdin.read()

rm_pats = [
    r"\brm\s+-[A-Za-z]*[rR][A-Za-z]*f",
    r"\brm\s+-[A-Za-z]*f[A-Za-z]*[rR]",
    r"\brm\s+-[rR]\s+-f\b",
    r"\brm\s+-f\s+-[rR]\b",
]
git_pats = [
    (r"\bgit\s+(?:-C\s+\S+\s+)?reset\s+--hard", "git reset --hard"),
    (r"\bgit\s+(?:-C\s+\S+\s+)?clean\s+-[A-Za-z]*f", "git clean -f"),
    (r"\bgit\s+(?:-C\s+\S+\s+)?checkout\s+(?:\S+\s+)?(?:--\s+)?\.(?:\s|$|;|&)", "git checkout ."),
    (r"\bgit\s+(?:-C\s+\S+\s+)?restore\s+(?:--?\S+\s+)*\.(?:\s|$|;|&)", "git restore ."),
    # token-boundary lookahead so --force-with-lease never matches, even when
    # a real --force appears earlier in the same command
    (r"\bgit\s+push\b[^;|&]*\s(?:--force|-f)(?=\s|$)", "git push --force"),
]

SAFE_TMP_PREFIXES = ("/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/")

def rm_risky_target(tail):
    """Scan ONLY the arguments of this rm invocation for high-risk targets.

    - truncate at the first shell separator so paths belonging to later
      commands or redirect targets are never attributed to rm
    - shlex-tokenize so quoted targets ("/etc/x", \x27/Users/y\x27) are seen
      with their quotes stripped
    - temp-dir paths are exempt: rm -rf of scratch space is routine
    """
    segment = re.split(r"&&|\|\||;|\|", tail)[0]
    try:
        tokens = shlex.split(segment)
    except ValueError:
        tokens = segment.split()
    skip_next = False
    for tok in tokens[1:]:
        if skip_next:
            skip_next = False
            continue
        if re.match(r"^\d*>>?$", tok):     # bare redirect operator: skip its target
            skip_next = True
            continue
        if re.match(r"^\d*>>?", tok):      # attached redirect (>/dev/null, 2>err)
            continue
        if tok.startswith("-"):
            continue
        if tok.startswith(("$HOME", "${HOME")):
            return tok
        if tok.startswith("$"):            # other variables: unknowable, stay silent
            continue
        if tok in (".", "*", "~", "/"):
            return tok
        if tok.startswith(SAFE_TMP_PREFIXES):
            continue
        if tok.startswith(("/", "~")) or ".." in tok:
            return tok
    return None

for pat in rm_pats:
    m = re.search(pat, cmd)
    if m:
        target = rm_risky_target(cmd[m.start():])
        if target:
            print("RM_RISKY\trm -rf\t" + target)
        else:
            print("RM\trm -rf\t")
        sys.exit(0)

for pat, label in git_pats:
    if re.search(pat, cmd):
        print("GIT\t" + label + "\t")
        sys.exit(0)
' 2>/dev/null) || MATCH=""
[ -z "$MATCH" ] && exit 0

CATEGORY=$(printf '%s' "$MATCH" | cut -f1)
PATTERN=$(printf '%s' "$MATCH" | cut -f2)
TARGET=$(printf '%s' "$MATCH" | cut -f3)

# --- Non-mutating checkpoint (tag HEAD + tag a stash-create commit) ---
CHECKPOINT=""
IN_GIT_REPO=false
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  IN_GIT_REPO=true
  # PID suffix: two guard firings in the same second must not collide
  TS="$(date +%Y%m%d-%H%M%S)-$$"
  TAG="auto-checkpoint/$TS"
  # -c tag.gpgsign=false: machines with signed-tags-by-default (install.sh
  # Phase 5.5) would otherwise fail to create a lightweight tag non-interactively
  if git -C "$PROJECT_DIR" -c tag.gpgsign=false tag "$TAG" 2>/dev/null; then
    CHECKPOINT="tag $TAG"
  fi
  # `git stash create` builds a stash commit WITHOUT modifying the working
  # tree. Never `git stash push` here — it would remove the dirty changes the
  # guarded command may depend on. The commit is preserved via a tag instead
  # of `git stash store` so the user's stash list is not polluted and their
  # next `git stash pop` can never restore our snapshot by accident.
  STASH_SHA=$(git -C "$PROJECT_DIR" stash create "auto-checkpoint-$TS" 2>/dev/null || true)
  if [ -n "$STASH_SHA" ]; then
    if git -C "$PROJECT_DIR" -c tag.gpgsign=false tag "$TAG-work" "$STASH_SHA" 2>/dev/null; then
      if [ -n "$CHECKPOINT" ]; then
        CHECKPOINT="$CHECKPOINT, work snapshot $TAG-work"
      else
        CHECKPOINT="work snapshot $TAG-work"
      fi
    fi
  fi

  # Prune auto-checkpoint tags older than PRUNE_DAYS (date is in the tag name)
  CUTOFF=$(python3 -c "import datetime; print((datetime.datetime.now()-datetime.timedelta(days=$PRUNE_DAYS)).strftime('%Y%m%d'))" 2>/dev/null || true)
  if [ -n "$CUTOFF" ]; then
    git -C "$PROJECT_DIR" tag -l 'auto-checkpoint/*' 2>/dev/null | while IFS= read -r old; do
      tagdate=$(printf '%s' "$old" | sed 's|auto-checkpoint/||' | cut -d- -f1)
      case "$tagdate" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
          if [ "$tagdate" -lt "$CUTOFF" ]; then
            git -C "$PROJECT_DIR" tag -d "$old" >/dev/null 2>&1 || true
          fi
          ;;
      esac
    done
  fi
fi

# Audit trail (self-gitignoring so logs never land in the user's repo)
if mkdir -p "$AUDIT_DIR" 2>/dev/null; then
  [ -f "$AUDIT_DIR/.gitignore" ] || echo '*' > "$AUDIT_DIR/.gitignore" 2>/dev/null || true
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) GUARD [$PATTERN] checkpoint=${CHECKPOINT:-none} cmd=$COMMAND" >> "$AUDIT_DIR/destructive-guard.log" 2>/dev/null || true
fi

emit_ask() {
  local reason="$1"
  REASON="$reason" python3 -c '
import json, os
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": os.environ["REASON"],
}}))
' 2>/dev/null || true
}

case "$CATEGORY" in
  RM_RISKY)
    if [ -n "$CHECKPOINT" ]; then
      emit_ask "rm -rf targets '$TARGET' (high-risk: absolute path, ~, .., * or .). Safety checkpoint created ($CHECKPOINT), but untracked files are NOT recoverable via /rewind or git. Confirm before proceeding."
    else
      emit_ask "rm -rf targets '$TARGET' (high-risk: absolute path, ~, .., * or .). No git checkpoint possible here — deleted files are NOT recoverable. Confirm before proceeding."
    fi
    ;;
  RM)
    # Relative-path / temp-dir cleanup: checkpoint made (if repo), no friction.
    exit 0
    ;;
  GIT)
    if [ "$IN_GIT_REPO" = "true" ] && [ -z "$CHECKPOINT" ]; then
      emit_ask "Destructive git command ($PATTERN) and no safety checkpoint could be created. Confirm before proceeding."
    fi
    # Checkpoint exists (or not a repo, where git will fail on its own):
    # stay silent so the normal permission flow applies.
    ;;
esac

exit 0
