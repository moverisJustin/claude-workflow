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

# ─── Stop-hook verify gate ───
echo "--- hook-stop-verify.sh ---"
STOP_VERIFY="$SCRIPT_DIR/hook-stop-verify.sh"
GATEPROJ="$TMP/gate-project"
GATEFILE="$GATEPROJ/.claude/audit/verify-gate"
mkdir -p "$GATEPROJ/.claude/audit"

OUT=$(echo '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$GATEPROJ" bash "$STOP_VERIFY")
if [ -z "$OUT" ]; then ok "no gate armed: silent (normal turns never blocked)"; else bad "blocked a stop with no gate armed"; fi

echo "attempts=0" > "$GATEFILE"
OUT=$(echo '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$GATEPROJ" bash "$STOP_VERIFY")
if printf '%s' "$OUT" | grep -q '"decision": *"block"'; then ok "armed gate: blocks the stop"; else bad "armed gate did not block (out=$OUT)"; fi
if grep -q "attempts=1" "$GATEFILE"; then ok "attempt counter incremented"; else bad "attempt counter not incremented"; fi

echo "attempts=3" > "$GATEFILE"
OUT=$(echo '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$GATEPROJ" bash "$STOP_VERIFY")
if printf '%s' "$OUT" | grep -q 'systemMessage' && [ ! -f "$GATEFILE" ]; then
  ok "escape hatch: gate disarms after max attempts (agent never trapped)"
else
  bad "escape hatch failed (out=$OUT gate-exists=$([ -f "$GATEFILE" ] && echo yes || echo no))"
fi

# Stale gate (crashed session): silently disarmed, no block
echo "attempts=0" > "$GATEFILE"
touch -t 202601010000 "$GATEFILE"
OUT=$(echo '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$GATEPROJ" bash "$STOP_VERIFY")
if [ -z "$OUT" ] && [ ! -f "$GATEFILE" ]; then
  ok "stale gate (>2h): silently disarmed"
else
  bad "stale gate not disarmed (out=$OUT gate-exists=$([ -f "$GATEFILE" ] && echo yes || echo no))"
fi

# Gate path containing a single quote must not break the staleness check
QPROJ="$TMP/o'brien-project"
mkdir -p "$QPROJ/.claude/audit"
echo "attempts=0" > "$QPROJ/.claude/audit/verify-gate"
touch -t 202601010000 "$QPROJ/.claude/audit/verify-gate"
OUT=$(echo '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="$QPROJ" bash "$STOP_VERIFY")
if [ -z "$OUT" ] && [ ! -f "$QPROJ/.claude/audit/verify-gate" ]; then
  ok "quoted project path: staleness check still works"
else
  bad "quoted project path broke the staleness check"
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

# ─── SessionStart: pre-v3 Memory Bank detection ───
echo "--- hook-session-start.sh (migrate detection) ---"
SS="$SCRIPT_DIR/hook-session-start.sh"

# v3-clean project: only the 3 durable files -> no migrate hint
V3P="$TMP/v3-project"
mkdir -p "$V3P/.claude/memory"
printf '# Project Context\n' > "$V3P/.claude/memory/projectContext.md"
printf '# Decision Log\n' > "$V3P/.claude/memory/decisionLog.md"
printf '# Conventions\n' > "$V3P/.claude/memory/conventions.md"
echo '{"git_enabled": false}' > "$V3P/.claude/project-config.json"
OUT=$(CLAUDE_PROJECT_DIR="$V3P" bash "$SS")
if ! printf '%s' "$OUT" | grep -q 'Pre-v3 Memory Bank'; then ok "v3-clean project: no migrate hint"; else bad "v3-clean project wrongly flagged for migration"; fi

# Old-layout project: has activeContext + progress -> migrate hint offered
OLDP="$TMP/old-project"
mkdir -p "$OLDP/.claude/memory"
printf '# Project Context\n' > "$OLDP/.claude/memory/projectContext.md"
printf '# Active\n' > "$OLDP/.claude/memory/activeContext.md"
printf '# Progress\n' > "$OLDP/.claude/memory/progress.md"
echo '{"git_enabled": false}' > "$OLDP/.claude/project-config.json"
OUT=$(CLAUDE_PROJECT_DIR="$OLDP" bash "$SS")
if printf '%s' "$OUT" | grep -q 'Pre-v3 Memory Bank'; then ok "old-layout project: migrate hint emitted"; else bad "old-layout project NOT flagged (out=$OUT)"; fi
if printf '%s' "$OUT" | grep -q '/memory-migrate'; then ok "hint names the /memory-migrate skill"; else bad "hint missing /memory-migrate"; fi
if printf '%s' "$OUT" | grep -q 'without confirmation'; then ok "hint says offer, not auto-run (state-change safety)"; else bad "hint missing the do-not-auto-run guard"; fi

# Dormant v2 project with NO project-config.json AND no projectContext.md
# (the realistic case — project-config predates old projects). Must still fire.
NOCFG="$TMP/nocfg-project"
mkdir -p "$NOCFG/.claude/memory"
printf '# Active\n' > "$NOCFG/.claude/memory/activeContext.md"
OUT=$(CLAUDE_PROJECT_DIR="$NOCFG" bash "$SS")
if printf '%s' "$OUT" | grep -q 'Pre-v3 Memory Bank'; then ok "no-config dormant project (no projectContext): still flagged"; else bad "no-config dormant project missed the migrate hint"; fi

# False-positive guard: a v3-clean project with an unrelated root tasks/todo.md
# must NOT be flagged (detection is scoped to .claude/memory/).
FP="$TMP/fp-project"
mkdir -p "$FP/.claude/memory" "$FP/tasks"
printf '# Project Context\n' > "$FP/.claude/memory/projectContext.md"
printf '# Conventions\n' > "$FP/.claude/memory/conventions.md"
printf '# todo\n' > "$FP/tasks/todo.md"
echo '{"git_enabled": false}' > "$FP/.claude/project-config.json"
OUT=$(CLAUDE_PROJECT_DIR="$FP" bash "$SS")
if ! printf '%s' "$OUT" | grep -q 'Pre-v3 Memory Bank'; then ok "generic root tasks/todo.md does not false-positive on a v3 project"; else bad "root tasks/ file wrongly flagged v3 project"; fi

# Resilience: a broken .git must not abort the hook before the migrate check.
BROKEN="$TMP/broken-git"
mkdir -p "$BROKEN/.claude/memory" "$BROKEN/.git"   # .git is a dir but not a valid repo
printf '# Project Context\n' > "$BROKEN/.claude/memory/projectContext.md"
printf '# Progress\n' > "$BROKEN/.claude/memory/progress.md"
echo '{"git_enabled": true}' > "$BROKEN/.claude/project-config.json"
OUT=$(CLAUDE_PROJECT_DIR="$BROKEN" bash "$SS")
if printf '%s' "$OUT" | grep -q 'Pre-v3 Memory Bank'; then ok "broken .git does not abort before the migrate check"; else bad "broken .git aborted the hook (git-status set-e trap)"; fi

echo "--- hook-destructive-guard.sh: PUBLISH gate ---"
# The mechanical containment that makes unlocking /task-done safe. Must be
# SILENT unless this branch's charter actually has an open cross-review — a
# gate that fires on every push is friction that trains click-through.
PUBREPO="$(mktemp -d "${TMPDIR:-/tmp}/pubgate.XXXXXX")"
git -C "$PUBREPO" init -q . 2>/dev/null
mkdir -p "$PUBREPO/.claude"
pub_out() { bash_payload "$1" | CLAUDE_PROJECT_DIR="$PUBREPO" bash "$GUARD" 2>/dev/null; }

OUT=$(pub_out "git push origin HEAD")
[ -z "$OUT" ] && ok "silent: no task-context.md" || bad "asked with no task-context ($OUT)"

printf '# Task\n## Objective\nx\n' > "$PUBREPO/.claude/task-context.md"
OUT=$(pub_out "git push origin HEAD")
[ -z "$OUT" ] && ok "silent: legacy charter with no Checkpoints section" || bad "legacy charter was gated ($OUT)"

printf '# Task\n## Checkpoints\n- [ ] cross-review: pending\n\n## Loops\n' > "$PUBREPO/.claude/task-context.md"
OUT=$(pub_out "git push origin HEAD")
if printf '%s' "$OUT" | grep -q '"ask"'; then ok "asks on push with open cross-review"; else bad "open cross-review did not gate the push"; fi
OUT=$(pub_out "gh pr create --fill")
if printf '%s' "$OUT" | grep -q '"ask"'; then ok "asks on gh pr create with open cross-review"; else bad "open cross-review did not gate gh pr create"; fi

printf '# Task\n## Checkpoints\n- [~] waived: solo repo, no second reviewer\n\n## Loops\n' > "$PUBREPO/.claude/task-context.md"
OUT=$(pub_out "git push origin HEAD")
[ -z "$OUT" ] && ok "silent once cross-review is waived" || bad "waived cross-review still gated ($OUT)"

printf '# Task\n## Checkpoints\n- [x] cross-review: codex+kimi, 0 confirmed\n\n## Loops\n' > "$PUBREPO/.claude/task-context.md"
OUT=$(pub_out "git push origin HEAD")
[ -z "$OUT" ] && ok "silent once cross-review is done" || bad "completed cross-review still gated ($OUT)"

# Force pushes are destructive AND a publication. They classify as GIT (the more
# serious category), which used to mean they never reached the publish check —
# so `git push --force` slipped past the cross-review gate that plain `git push`
# was stopped by. The bypass was exactly one flag wide.
printf '# Task\n## Checkpoints\n- [ ] cross-review: pending\n' > "$PUBREPO/.claude/task-context.md"
for c in "git push --force origin HEAD" "git push --force-with-lease origin HEAD"; do
  OUT=$(pub_out "$c")
  if printf '%s' "$OUT" | grep -q 'cross-review'; then ok "gated: $c"; else bad "force variant bypassed the cross-review gate: $c"; fi
done
printf '# Task\n## Checkpoints\n- [x] cross-review: done\n' > "$PUBREPO/.claude/task-context.md"
OUT=$(pub_out "git push --force origin HEAD")
if printf '%s' "$OUT" | grep -q 'cross-review'; then bad "force push gated after cross-review resolved"; else ok "force push silent once cross-review resolved"; fi

# Pushing must not litter the repo with recovery tags: nothing local is at risk.
printf '# Task\n## Checkpoints\n- [ ] cross-review: pending\n' > "$PUBREPO/.claude/task-context.md"
PT1=$(git -C "$PUBREPO" tag -l 'auto-checkpoint/*' | wc -l | tr -d ' ')
pub_out "git push origin HEAD" >/dev/null
PT2=$(git -C "$PUBREPO" tag -l 'auto-checkpoint/*' | wc -l | tr -d ' ')
[ "$PT1" = "$PT2" ] && ok "push creates no auto-checkpoint tag" || bad "push tagged a checkpoint ($PT1 -> $PT2)"
rm -rf "$PUBREPO"

echo "--- hook-plan-gate.sh ---"
# NOTE ON SCOPE: these assert the hook's OUTPUT contract. They cannot prove the
# CLI acts on it — that was established separately by a live spike (deny blocks
# ExitPlanMode; the reason reaches the caller) and must be re-checked live after
# any install. A green run here is necessary, not sufficient.
PGATE="$SCRIPT_DIR/hook-plan-gate.sh"
PG="$(mktemp -d "${TMPDIR:-/tmp}/plangate.XXXXXX")"
git -C "$PG" init -q . 2>/dev/null
git -C "$PG" checkout -qb feature/gate 2>/dev/null
mkdir -p "$PG/.claude/audit"
printf '# charter\n' > "$PG/.claude/task-context.md"
PGT="$PG/t.jsonl"

pg_payload() {
  D="$1" T="$2" python3 -c '
import json, os
print(json.dumps({
    "session_id": "test", "hook_event_name": "PreToolUse",
    "tool_name": "ExitPlanMode", "cwd": os.environ["D"],
    "transcript_path": os.environ["T"], "tool_input": {"plan": "x"},
}))'
}
pg_run() { pg_payload "$PG" "$PGT" | bash "$PGATE" 2>/dev/null; }
pg_decision() {
  python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("none"); raise SystemExit
try: print(json.loads(raw)["hookSpecificOutput"]["permissionDecision"])
except Exception: print("unparseable")'
}
pg_reset() { rm -f "$PG/.claude/audit/plan-gate-denials"; }
# A completed Skill call = tool_use plus a non-error tool_result.
pg_skill() { printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","id":"i%s","input":{"skill":"%s"}}]}}\n{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"i%s","is_error":%s}]}}\n' "$2" "$1" "$2" "${3:-false}"; }

printf '{"type":"assistant","message":{"content":[]}}\n' > "$PGT"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "deny" ] && ok "denies when no checkpoint ran" || bad "no-checkpoint case gave '$D' (want deny)"

# The gate must NEVER emit allow: on ExitPlanMode a hook allow satisfies
# requiresUserInteraction and would skip plan approval entirely.
OUT="$(printf '{"type":"assistant","message":{"content":[]}}\n' > "$PGT"; pg_run)"; pg_reset
if printf '%s' "$OUT" | grep -q '"allow"'; then bad "gate emitted allow (would SKIP plan approval)"; else ok "never emits allow"; fi

{ pg_skill clarify 1; pg_skill anythingelse 2; } > "$PGT"
printf '\n## Checkpoints\n- [~] plan-review: waived — below complexity bar\n' >> "$PG/.claude/task-context.md"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "none" ] && ok "silent when checkpoints ran and plan-review waived" || bad "satisfied case gave '$D' (want none)"

# Credit COMPLETION, not invocation — an errored Skill must not satisfy the gate.
{ pg_skill clarify 1; pg_skill anythingelse 2 true; } > "$PGT"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "deny" ] && ok "errored Skill call does not credit the checkpoint" || bad "errored call gave '$D' (want deny)"

# <command-name> must be read from USER messages only. Assistant prose ABOUT the
# tag would otherwise let the gate satisfy itself (hit live while building this).
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"matches <command-name>/clarify</command-name> and <command-name>/anythingelse</command-name>"}]}}\n' > "$PGT"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "deny" ] && ok "assistant prose about <command-name> cannot self-satisfy" || bad "assistant prose satisfied the gate ('$D')"

printf '{"type":"user","message":{"content":[{"type":"text","text":"<command-name>/clarify</command-name>"}]}}\n{"type":"user","message":{"content":[{"type":"text","text":"<command-name>/anythingelse</command-name>"}]}}\n' > "$PGT"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "none" ] && ok "user-typed slash commands satisfy the gate" || bad "user-typed commands gave '$D' (want none)"

# plan-review is ADVISORY: it is surfaced but never denies on its own. Recording
# its waiver means editing task-context.md, which plan mode hard-denies — a
# blocking check would have been unsatisfiable for a genuinely below-bar plan
# except by burning the escape hatch.
{ pg_skill clarify 1; pg_skill anythingelse 2; } > "$PGT"
printf '## Checkpoints\n- [ ] plan-review: never ran\n' > "$PG/.claude/task-context.md"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "none" ] && ok "missing plan-review alone does NOT deny (advisory)" || bad "plan-review denied on its own ('$D')"

# Waiver SCOPING still decides whether plan-review is credited — it just shows up
# as advisory text rather than a denial. Regression: the first version searched
# the WHOLE charter for any `- [~] waived:`, so a waived Acceptance item credited
# plan-review. Both foreign reviewers flagged it independently; reproduced first.
{ pg_skill anythingelse 2; } > "$PGT"   # clarify missing -> denial, so we can read the text

printf '## Acceptance\n- [~] waived: an unrelated acceptance item\n\n## Checkpoints\n- [ ] plan-review: never ran\n' > "$PG/.claude/task-context.md"
OUT="$(pg_run)"; pg_reset
if printf '%s' "$OUT" | grep -q 'plan-review'; then ok "waiver OUTSIDE ## Checkpoints does not credit plan-review"; else bad "unrelated waiver credited plan-review"; fi

printf '## Checkpoints\n- [~] cross-review: waived — solo repo\n- [ ] plan-review: never ran\n' > "$PG/.claude/task-context.md"
OUT="$(pg_run)"; pg_reset
if printf '%s' "$OUT" | grep -q 'plan-review'; then ok "waiver of a DIFFERENT checkpoint does not credit plan-review"; else bad "cross-review waiver credited plan-review"; fi

printf '## Checkpoints\n- [~] plan-review: waived — below complexity bar\n' > "$PG/.claude/task-context.md"
OUT="$(pg_run)"; pg_reset
if printf '%s' "$OUT" | grep -q 'plan-review'; then bad "valid plan-review waiver was ignored"; else ok "correctly-scoped plan-review waiver is credited"; fi

# A launched-but-never-returned Skill is NOT a completed checkpoint.
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","id":"z1","input":{"skill":"clarify"}}]}}\n{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","id":"z2","input":{"skill":"anythingelse"}}]}}\n' > "$PGT"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "deny" ] && ok "in-flight Skill (no tool_result) does not satisfy the gate" || bad "unreturned Skill counted as completed ('$D')"

# Escape-hatch state must not leak between sessions.
printf '{"type":"assistant","message":{"content":[]}}\n' > "$PGT"
pg_reset
pg_run >/dev/null; pg_run >/dev/null; pg_run >/dev/null   # exhaust for session "test"
D="$(D="$PG" T="$PGT" python3 -c '
import json, os
print(json.dumps({"session_id": "a-different-session", "hook_event_name": "PreToolUse",
                  "tool_name": "ExitPlanMode", "cwd": os.environ["D"],
                  "transcript_path": os.environ["T"], "tool_input": {"plan": "x"}}))' \
  | bash "$PGATE" 2>/dev/null | pg_decision)"
[ "$D" = "deny" ] && ok "denial counter is per-session (fresh session still gates)" || bad "counter leaked across sessions ('$D')"
pg_reset

# Restore a satisfied charter for the tests that follow.
{ pg_skill clarify 1; pg_skill anythingelse 2; } > "$PGT"
printf '# charter\n## Checkpoints\n- [~] plan-review: waived — below complexity bar\n' > "$PG/.claude/task-context.md"

# Evidence is scoped to the plan EPISODE: checkpoints before a previous
# ExitPlanMode belong to that episode, not this one.
{ pg_skill clarify 1; pg_skill anythingelse 2; printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ExitPlanMode","id":"e1"}]}}\n'; } > "$PGT"
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "deny" ] && ok "prior-episode checkpoints do not carry over" || bad "stale episode evidence counted ('$D')"

# Escape hatch: a gate nobody can satisfy must stand down.
printf '{"type":"assistant","message":{"content":[]}}\n' > "$PGT"
pg_reset
pg_run >/dev/null; pg_run >/dev/null; pg_run >/dev/null
D="$(pg_run | pg_decision)"
[ "$D" = "none" ] && ok "disarms after 3 denials" || bad "gate still '$D' after 3 denials (wedge risk)"
pg_reset

# Blast-radius guards.
NOCTX="$(mktemp -d "${TMPDIR:-/tmp}/plangate-noctx.XXXXXX")"
git -C "$NOCTX" init -q . 2>/dev/null
D="$(D="$NOCTX" T="$PGT" pg_payload "$NOCTX" "$PGT" | bash "$PGATE" 2>/dev/null | pg_decision)"
[ "$D" = "none" ] && ok "silent with no task-context.md" || bad "gated a repo with no task-context ('$D')"
rm -rf "$NOCTX"

git -C "$PG" checkout -qb main 2>/dev/null || git -C "$PG" checkout -q main 2>/dev/null
D="$(pg_run | pg_decision)"; pg_reset
[ "$D" = "none" ] && ok "silent on a protected branch" || bad "gated on main ('$D')"
git -C "$PG" checkout -q feature/gate 2>/dev/null

D="$(printf 'not json at all' | bash "$PGATE" 2>/dev/null | pg_decision)"
[ "$D" = "none" ] && ok "fails open on garbage stdin" || bad "garbage stdin produced '$D' (must fail open)"

D="$(printf '' | bash "$PGATE" 2>/dev/null | pg_decision)"
[ "$D" = "none" ] && ok "fails open on empty stdin" || bad "empty stdin produced '$D' (must fail open)"

rm -rf "$PG"

echo ""
echo "Passed: $pass  Failed: $fail"
[ "$fail" -ne 0 ] && exit 1
echo "All hook contract tests passed."
