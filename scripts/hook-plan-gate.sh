#!/usr/bin/env bash
# hook-plan-gate.sh — PreToolUse gate on ExitPlanMode.
#
# WHY THIS EXISTS: the planning checkpoints (/clarify, /anythingelse) were
# documented as mandatory and ran before 11 of 77 real plan approvals. They were
# never enforced — prose in a skill file that itself never loaded. This is the
# enforcement point: the moment a plan is approved.
#
# CONTRACT (verified empirically, not from docs — see the spike in the plan):
#   - permissionDecision "deny" IS honored on ExitPlanMode; the reason reaches
#     the caller. "ask" is NOT — ExitPlanMode declares requiresUserInteraction(),
#     so the bridge returns ask unconditionally and DISCARDS the hook result.
#     A gate built on "ask" is silent theatre. Hence deny.
#   - "allow" is NEVER emitted. On ExitPlanMode a hook allow satisfies the
#     user-interaction requirement and would SKIP plan approval entirely.
#   - The payload carries transcript_path, prompt_id, session_id, cwd,
#     permission_mode, tool_name, tool_input, tool_use_id. It does NOT carry
#     agent_id, so there is no agent-based subagent guard here — none is needed,
#     because subagents do not have the ExitPlanMode tool at all.
#
# EVIDENCE IS THE TRANSCRIPT, NOT A SELF-REPORT. An earlier design read a
# checkpoint block out of .claude/task-context.md. That is unwritable during
# plan mode (so a deny would deadlock with no way to satisfy it) and is one Edit
# from being forged. This reads what actually happened.
#
# Fail-open on every error: a broken gate must never block work.

set -u

GATE_MAX_DENIALS="${GATE_MAX_DENIALS:-3}"

# Fail-open helper: emit nothing, exit 0.
allow_through() { exit 0; }

PAYLOAD="$(cat 2>/dev/null)" || allow_through
[ -n "$PAYLOAD" ] || allow_through

command -v python3 >/dev/null 2>&1 || allow_through

# cwd from the payload; fall back to the process cwd.
PROJECT_DIR="$(printf '%s' "$PAYLOAD" | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("cwd","") or "")
except Exception: print("")
' 2>/dev/null)" || allow_through
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(pwd)"

# --- guard 1 (cheapest — a stat): only gate real task branches ---------------
# No task-context.md means this is not tracked work: a scratch repo, a one-off
# fix, someone else's project. Ordered first so those pay nothing.
TASK_CONTEXT="$PROJECT_DIR/.claude/task-context.md"
[ -f "$TASK_CONTEXT" ] || allow_through

# --- guard 2: never gate on a protected branch -------------------------------
# Resolved OFFLINE. resolve-base-branch.sh --no-cache skips reading AND writing
# the cache, which would put a gh API call in the approval path of every plan
# and make the gate silently inert whenever the network is down. Read the cache
# if it exists; otherwise fall back to local refs. Never the network.
BRANCH="$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)" || allow_through
[ -n "$BRANCH" ] || allow_through

PROTECTED=""
CONFIG="$PROJECT_DIR/.claude/project-config.json"
if [ -f "$CONFIG" ]; then
  PROTECTED="$(python3 -c '
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    v=d.get("protected_branches") or d.get("base_branch") or ""
    print(" ".join(v) if isinstance(v,list) else str(v))
except Exception: print("")
' "$CONFIG" 2>/dev/null)"
fi
if [ -z "$PROTECTED" ]; then
  # Local-refs fallback: the remote HEAD symref, read from disk.
  PROTECTED="$(git -C "$PROJECT_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
  [ -n "$PROTECTED" ] || PROTECTED="main master develop"
fi
for p in $PROTECTED; do
  [ "$BRANCH" = "$p" ] && allow_through
done

# --- escape hatch: disarm after N denials ------------------------------------
# Mirrors hook-stop-verify.sh's MAX_ATTEMPTS. A gate nobody can satisfy is worse
# than no gate. Lives in .claude/audit/, which is gitignored AND which hooks can
# write during plan mode (the model cannot).
AUDIT_DIR="$PROJECT_DIR/.claude/audit"
COUNTER="$AUDIT_DIR/plan-gate-denials"
DENIALS=0
if [ -f "$COUNTER" ]; then
  DENIALS="$(cat "$COUNTER" 2>/dev/null || echo 0)"
  case "$DENIALS" in ''|*[!0-9]*) DENIALS=0 ;; esac
fi
if [ "$DENIALS" -ge "$GATE_MAX_DENIALS" ]; then
  rm -f "$COUNTER" 2>/dev/null || true
  allow_through
fi

# --- evaluate the checkpoints ------------------------------------------------
MISSING="$(printf '%s' "$PAYLOAD" | TASK_CONTEXT="$TASK_CONTEXT" python3 -c '
import json, os, re, sys

REQUIRED = ["clarify", "anythingelse"]
# plan-review is complexity-triggered by a locked decision that a hook cannot
# evaluate, so it is satisfied by a real run OR an explicit waiver line.
CONDITIONAL = "plan-review"

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)                      # fail open

tpath = payload.get("transcript_path") or ""
if not tpath or not os.path.exists(tpath):
    sys.exit(0)                      # fail open

# ---- read the transcript ----------------------------------------------------
try:
    lines = open(tpath, errors="ignore").read().splitlines()
except Exception:
    sys.exit(0)

records = []
for ln in lines:
    try:
        records.append(json.loads(ln))
    except Exception:
        continue

# ---- episode window ---------------------------------------------------------
# Scope evidence to the PLAN EPISODE, not to prompt_id. A planning phase spans
# several user prompts (you run /clarify, the user answers -> new prompt, you
# plan, then exit), so prompt-scoping would false-deny nearly every time and
# train the disarm hatch into the normal path. The window is everything since
# the previous ExitPlanMode; this hook fires BEFORE the current call is
# recorded, so the last one present belongs to the previous episode.
start = 0
for i, rec in enumerate(records):
    content = (rec.get("message") or {}).get("content")
    if not isinstance(content, list):
        continue
    for b in content:
        if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "ExitPlanMode":
            start = i + 1

window = records[start:]

# ---- collect evidence -------------------------------------------------------
# errors[tool_use_id] = True when the call came back an error. Credit COMPLETION,
# not invocation: a Skill that errored, or a /plan-review whose backend timed
# out, must not satisfy the gate.
errors, skill_calls, typed = {}, [], set()

for rec in window:
    rtype = rec.get("type")
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, str):
        content = [{"type": "text", "text": content}]
    if not isinstance(content, list):
        continue
    for b in content:
        if not isinstance(b, dict):
            continue
        btype = b.get("type")
        if btype == "tool_use" and b.get("name") == "Skill":
            name = (b.get("input") or {}).get("skill")
            if name:
                skill_calls.append((b.get("id"), name.split(":")[-1]))
        elif btype == "tool_result":
            if b.get("is_error"):
                errors[b.get("tool_use_id")] = True
        elif btype == "text" and rtype == "user":
            # User-typed slash commands. Scoped to USER messages on purpose:
            # assistant prose ABOUT <command-name> would otherwise self-satisfy
            # the gate (observed live while building this).
            for m in re.findall(r"<command-name>/?([a-z0-9:-]+)</command-name>", b.get("text") or ""):
                typed.add(m.split(":")[-1])

def satisfied(step):
    if step in typed:
        return True
    return any(n == step and not errors.get(tid) for tid, n in skill_calls)

missing = [s for s in REQUIRED if not satisfied(s)]

if not satisfied(CONDITIONAL):
    # Accept an explicit waiver in the charter for the below-the-bar case.
    try:
        tc = open(os.environ["TASK_CONTEXT"], errors="ignore").read()
    except Exception:
        tc = ""
    if not re.search(r"^\s*-\s*\[~\]\s*waived:.*", tc, re.M | re.I):
        missing.append(CONDITIONAL)

print(" ".join(missing))
' 2>/dev/null)" || allow_through

[ -n "$MISSING" ] || { rm -f "$COUNTER" 2>/dev/null || true; allow_through; }

# --- deny --------------------------------------------------------------------
mkdir -p "$AUDIT_DIR" 2>/dev/null || true
echo "$((DENIALS + 1))" > "$COUNTER" 2>/dev/null || true

REMAINING=$((GATE_MAX_DENIALS - DENIALS - 1))
MISSING="$MISSING" REMAINING="$REMAINING" python3 -c '
import json, os
missing = os.environ["MISSING"].split()
names = {
    "clarify": "/clarify — ask the user the questions that close the gaps",
    "anythingelse": "/anythingelse — the wildcard checkpoint",
    "plan-review": "/plan-review — foreign-model review (or record `- [~] waived: below complexity bar` in task-context.md if under the bar)",
}
lines = "\n".join("  - " + names.get(m, m) for m in missing)
remaining = os.environ["REMAINING"]
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": (
        "Planning checkpoints not run for this plan episode:\n" + lines +
        "\n\nRun them, then call ExitPlanMode again. "
        "(Gate disarms after " + remaining + " more denial(s) if it is wrong.)"
    ),
}}))
' 2>/dev/null || allow_through
exit 0
