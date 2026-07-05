#!/usr/bin/env bash
set -uo pipefail

# Contract tests for the hook scripts. Pipes real hook payloads (JSON on
# stdin, per the Claude Code hooks contract) into each script and asserts
# behavior. Pure bash + python3 (the same deps the hooks themselves have).
# Exits non-zero on any failure. Run with /bin/bash on macOS to verify
# bash 3.2 compatibility.
#
# These tests exist because the previous hook layer consumed env vars that
# were never set and silently no-opped for months. Any regression back to a
# wrong contract must fail loudly here.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/hook-destructive-guard.sh"
AUDIT="$SCRIPT_DIR/hook-audit.sh"
DRIFT="$SCRIPT_DIR/hook-drift-watch.sh"
PRECOMPACT="$SCRIPT_DIR/hook-precompact.sh"
PRETTIER="$SCRIPT_DIR/hook-prettier.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok()   { echo "  PASS: $1"; pass=$((pass + 1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail + 1)); }

# payload <command> — build a PreToolUse Bash payload safely (handles quotes)
bash_payload() {
  CMD="$1" python3 -c '
import json, os
print(json.dumps({
    "session_id": "test", "hook_event_name": "PreToolUse",
    "tool_name": "Bash", "tool_input": {"command": os.environ["CMD"]},
}))'
}

edit_payload() {
  FP="$1" python3 -c '
import json, os
print(json.dumps({
    "session_id": "test", "hook_event_name": "PreToolUse",
    "tool_name": "Edit", "tool_input": {"file_path": os.environ["FP"]},
}))'
}

echo "=== test-hooks.sh ==="

# --- Fixture: a git repo with a commit, a dirty tracked file, an untracked file ---
REPO="$TMP/repo"
mkdir -p "$REPO"
git -C "$REPO" init --quiet
git -C "$REPO" -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
  commit --allow-empty -qm init
echo "tracked" > "$REPO/tracked.txt"
git -C "$REPO" add tracked.txt
git -C "$REPO" -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
  commit -qm "add tracked"
echo "dirty edit" >> "$REPO/tracked.txt"
echo "untracked" > "$REPO/untracked.txt"

# ─── Destructive guard ───
echo "--- hook-destructive-guard.sh ---"

OUT=$(bash_payload "ls -la" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
RC=$?
if [ $RC -eq 0 ] && [ -z "$OUT" ]; then ok "benign command: silent allow"; else bad "benign command (rc=$RC out=$OUT)"; fi

OUT=$(bash_payload "git reset --hard HEAD" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
RC=$?
TAGS=$(git -C "$REPO" tag -l 'auto-checkpoint/*' | grep -cv -- '-work$' || true)
WORK_TAGS=$(git -C "$REPO" tag -l 'auto-checkpoint/*-work' | wc -l | tr -d ' ')
STASHES=$(git -C "$REPO" stash list | wc -l | tr -d ' ')
if [ $RC -eq 0 ] && [ -z "$OUT" ]; then ok "git reset --hard: silent (normal permission flow preserved)"; else bad "git reset --hard (rc=$RC out=$OUT)"; fi
if [ "$TAGS" -ge 1 ]; then ok "git reset --hard: checkpoint tag created"; else bad "git reset --hard: no checkpoint tag"; fi
if [ "$WORK_TAGS" -ge 1 ]; then ok "git reset --hard: dirty tree snapshotted (tagged stash commit)"; else bad "git reset --hard: no work snapshot tag"; fi
if [ "$STASHES" -eq 0 ]; then ok "stash list NOT polluted (user's stash pop stays safe)"; else bad "guard wrote to the stash list"; fi
if grep -q "dirty edit" "$REPO/tracked.txt" && [ -f "$REPO/untracked.txt" ]; then
  ok "checkpoint did NOT mutate the working tree"
else
  bad "checkpoint mutated the working tree (stash push regression)"
fi
if [ -f "$REPO/.claude/audit/.gitignore" ]; then ok "audit dir is self-gitignoring"; else bad "audit dir missing .gitignore (secrets could be committed)"; fi

OUT=$(bash_payload "cd sub && git reset --hard HEAD~1" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
TAGS2=$(git -C "$REPO" tag -l 'auto-checkpoint/*' | wc -l | tr -d ' ')
if [ "$TAGS2" -gt "$TAGS" ]; then ok "compound command detected (prefix-match regression guard)"; else bad "compound command NOT detected"; fi

OUT=$(bash_payload "rm -rf /etc/something" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if printf '%s' "$OUT" | grep -q '"permissionDecision": *"ask"'; then ok "rm -rf absolute path: escalates to ask"; else bad "rm -rf absolute path: no ask (out=$OUT)"; fi

OUT=$(bash_payload "rm -rf node_modules" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if [ -z "$OUT" ]; then ok "rm -rf relative path: silent (checkpoint only)"; else bad "rm -rf relative path: unexpected output ($OUT)"; fi

OUT=$(bash_payload "rm -rf .." | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if printf '%s' "$OUT" | grep -q '"permissionDecision": *"ask"'; then ok "rm -rf ..: escalates to ask"; else bad "rm -rf ..: no ask"; fi

# QUOTED absolute targets must still be caught (Claude habitually quotes paths)
OUT=$(bash_payload 'rm -rf "/Users/someone/project-dir"' | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if printf '%s' "$OUT" | grep -q '"permissionDecision": *"ask"'; then ok "rm -rf quoted absolute path: escalates to ask"; else bad "rm -rf quoted absolute path: BYPASSED the gate"; fi

OUT=$(bash_payload 'rm -rf "$HOME"' | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if printf '%s' "$OUT" | grep -q '"permissionDecision": *"ask"'; then ok 'rm -rf "$HOME": escalates to ask'; else bad 'rm -rf "$HOME": no ask'; fi

# Temp-dir cleanup is routine agent behavior — must stay silent
OUT=$(bash_payload "rm -rf /tmp/scratch-xyz" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if [ -z "$OUT" ]; then ok "rm -rf /tmp path: silent (temp exemption)"; else bad "rm -rf /tmp path: false-positive ask"; fi

# Redirects and later commands must not be attributed to rm
OUT=$(bash_payload "rm -rf dist > /dev/null" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if [ -z "$OUT" ]; then ok "rm -rf dist > /dev/null: silent (redirect not a target)"; else bad "redirect target misattributed to rm"; fi

OUT=$(bash_payload "rm -rf build && cp -R dist /usr/local/share/app" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
if [ -z "$OUT" ]; then ok "rm -rf build && cp .. /usr/..: silent (scan stops at separator)"; else bad "later command's path misattributed to rm"; fi

# Tree-wiping git variants the original prefix patterns missed
T0=$(git -C "$REPO" tag -l 'auto-checkpoint/*' | grep -cv -- '-work$' || true)
bash_payload "git checkout HEAD -- ." | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD" >/dev/null
T1=$(git -C "$REPO" tag -l 'auto-checkpoint/*' | grep -cv -- '-work$' || true)
if [ "$T1" -gt "$T0" ]; then ok "git checkout HEAD -- .: checkpointed"; else bad "git checkout HEAD -- .: not detected"; fi

bash_payload "git push --force origin main || git push --force-with-lease origin main" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD" >/dev/null
T2=$(git -C "$REPO" tag -l 'auto-checkpoint/*' | grep -cv -- '-work$' || true)
if [ "$T2" -gt "$T1" ]; then ok "real --force before --force-with-lease: still detected"; else bad "--force masked by later --force-with-lease"; fi

TAGS_BEFORE=$(git -C "$REPO" tag -l 'auto-checkpoint/*' | wc -l | tr -d ' ')
OUT=$(bash_payload "git push --force-with-lease origin main" | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
TAGS_AFTER=$(git -C "$REPO" tag -l 'auto-checkpoint/*' | wc -l | tr -d ' ')
if [ -z "$OUT" ] && [ "$TAGS_AFTER" -eq "$TAGS_BEFORE" ]; then ok "--force-with-lease: not treated as destructive"; else bad "--force-with-lease misclassified"; fi

# git_enabled=false opt-out
NOGIT="$TMP/nogit-project"
mkdir -p "$NOGIT/.claude"
echo '{"git_enabled": false}' > "$NOGIT/.claude/project-config.json"
OUT=$(bash_payload "git reset --hard HEAD" | CLAUDE_PROJECT_DIR="$NOGIT" bash "$GUARD")
if [ -z "$OUT" ]; then ok "git_enabled=false project: guard skipped"; else bad "git_enabled=false project: guard ran anyway"; fi

# fail-open on garbage stdin
OUT=$(printf 'not json' | CLAUDE_PROJECT_DIR="$REPO" bash "$GUARD")
RC=$?
if [ $RC -eq 0 ] && [ -z "$OUT" ]; then ok "garbage stdin: fail-open"; else bad "garbage stdin: rc=$RC out=$OUT"; fi

# ─── Audit log ───
echo "--- hook-audit.sh ---"
PROJ="$TMP/audit-project"
mkdir -p "$PROJ"
bash_payload "npm test" | CLAUDE_PROJECT_DIR="$PROJ" bash "$AUDIT"
if grep -q "BASH npm test" "$PROJ/.claude/audit/commands.log" 2>/dev/null; then ok "Bash command logged to commands.log"; else bad "Bash command not logged"; fi
edit_payload "/tmp/some/file.ts" | CLAUDE_PROJECT_DIR="$PROJ" bash "$AUDIT"
if grep -q "FILE_WRITE /tmp/some/file.ts" "$PROJ/.claude/audit/files.log" 2>/dev/null; then ok "Edit file path logged to files.log"; else bad "Edit file path not logged"; fi

# ─── Drift watch ───
echo "--- hook-drift-watch.sh ---"
OUT=$(bash_payload "npm test" | CLAUDE_PROJECT_DIR="$PROJ" bash "$DRIFT")
if [ -z "$OUT" ]; then ok "non-commit command: silent"; else bad "non-commit command produced output"; fi
OUT=$(bash_payload "git commit -m x" | CLAUDE_PROJECT_DIR="$PROJ" bash "$DRIFT")
if [ -z "$OUT" ]; then ok "commit without Memory Bank: silent"; else bad "commit without Memory Bank produced output"; fi

# ─── Compaction pair ───
# PreCompact consumes NO hook output (only decision:block) — the snapshot is
# a side effect; the recovery directive travels via SessionStart(compact).
echo "--- hook-precompact.sh + hook-compact-resume.sh ---"
COMPACT_RESUME="$SCRIPT_DIR/hook-compact-resume.sh"

OUT=$(echo '{"hook_event_name":"PreCompact"}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$PRECOMPACT")
if [ -z "$OUT" ] && [ ! -f "$PROJ/.claude/memory/compaction-snapshot.md" ]; then
  ok "PreCompact without Memory Bank: silent, no snapshot"
else
  bad "PreCompact without Memory Bank misbehaved (out=$OUT)"
fi

mkdir -p "$REPO/.claude/memory"
OUT=$(echo '{"hook_event_name":"PreCompact"}' | CLAUDE_PROJECT_DIR="$REPO" bash "$PRECOMPACT")
if [ -z "$OUT" ] && grep -q '^# Compaction Snapshot' "$REPO/.claude/memory/compaction-snapshot.md" 2>/dev/null \
   && grep -q '\*\*Branch\*\*' "$REPO/.claude/memory/compaction-snapshot.md"; then
  ok "PreCompact with Memory Bank: writes git-state snapshot"
else
  bad "PreCompact snapshot missing or malformed"
fi

OUT=$(echo '{"hook_event_name":"SessionStart","source":"compact"}' | CLAUDE_PROJECT_DIR="$REPO" bash "$COMPACT_RESUME")
if printf '%s' "$OUT" | grep -q 'Post-compaction recovery' && printf '%s' "$OUT" | grep -q 'compaction-snapshot.md'; then
  ok "compact-resume: emits recovery directive referencing the snapshot"
else
  bad "compact-resume output wrong: $OUT"
fi

# ─── Prettier ───
echo "--- hook-prettier.sh ---"
echo "# doc" > "$TMP/sample.md"
OUT=$(edit_payload "$TMP/sample.md" | bash "$PRETTIER")
RC=$?
if [ $RC -eq 0 ]; then ok "markdown file without project prettier: silent exit 0"; else bad "prettier hook rc=$RC"; fi
OUT=$(edit_payload "$TMP/missing.py" | bash "$PRETTIER")
RC=$?
if [ $RC -eq 0 ] && [ -z "$OUT" ]; then ok "non-target extension: no-op"; else bad "non-target extension: rc=$RC out=$OUT"; fi

echo ""
echo "Passed: $pass  Failed: $fail"
[ "$fail" -ne 0 ] && exit 1
echo "All hook contract tests passed."
