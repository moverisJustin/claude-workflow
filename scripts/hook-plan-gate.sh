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

# Denials before the gate stands down. Override per-project or per-shell with
# GATE_MAX_DENIALS=<n>; documented in the README hooks table.
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
# Newline-separated + quoted: an unquoted `for p in $PROTECTED` word-splits a
# branch name containing whitespace and GLOB-EXPANDS one containing `*`
# (e.g. a `release/*` entry), silently failing the comparison.
printf '%s\n' "$PROTECTED" | tr ' ' '\n' | while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ "$BRANCH" = "$p" ] && exit 17
done
[ $? -eq 17 ] && allow_through

# --- escape hatch: disarm after N denials ------------------------------------
# Mirrors hook-stop-verify.sh's MAX_ATTEMPTS. A gate nobody can satisfy is worse
# than no gate. Lives in .claude/audit/, which is gitignored AND which hooks can
# write during plan mode (the model cannot).
AUDIT_DIR="$PROJECT_DIR/.claude/audit"
COUNTER="$AUDIT_DIR/plan-gate-denials"
# Scoped to the SESSION. A bare counter persisted across sessions and episodes,
# so denials from yesterday could arrive pre-exhausted (or, worse, silently
# spend the escape hatch of an unrelated plan).
SESSION_ID="$(printf '%s' "$PAYLOAD" | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("session_id","") or "none")
except Exception: print("none")
' 2>/dev/null)"
[ -n "$SESSION_ID" ] || SESSION_ID="none"

DENIALS=0
if [ -f "$COUNTER" ]; then
  RAW="$(cat "$COUNTER" 2>/dev/null || echo)"
  case "$RAW" in
    "$SESSION_ID:"*) DENIALS="${RAW#*:}" ;;
    *)               DENIALS=0 ;;   # different session: start fresh
  esac
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
# CRITICAL: anchor on the last SUCCESSFUL ExitPlanMode, not merely the last one
# recorded. A DENIED ExitPlanMode is itself written to the transcript, so
# anchoring on any occurrence made every denial reset the window and discard the
# checkpoints already earned: deny naming /anythingelse -> user runs it -> window
# now starts after the denial and contains only /anythingelse -> deny naming
# /clarify. A treadmill that can only be escaped by burning the disarm hatch.
# A denial comes back as a tool_result with is_error, so success == an
# ExitPlanMode tool_use whose result is not an error (or has no result yet).
epm_ids = {}          # index -> tool_use id
epm_errors = set()
for i, rec in enumerate(records):
    content = (rec.get("message") or {}).get("content")
    if not isinstance(content, list):
        continue
    for b in content:
        if not isinstance(b, dict):
            continue
        if b.get("type") == "tool_use" and b.get("name") == "ExitPlanMode":
            epm_ids[i] = b.get("id")
        elif b.get("type") == "tool_result" and b.get("is_error"):
            epm_errors.add(b.get("tool_use_id"))

start = 0
for i in sorted(epm_ids):
    if epm_ids[i] not in epm_errors:      # this approval actually went through
        start = i + 1

window = records[start:]

# ---- collect evidence -------------------------------------------------------
# errors[tool_use_id] = True when the call came back an error. Credit COMPLETION,
# not invocation: a Skill that errored, or a /plan-review whose backend timed
# out, must not satisfy the gate.
errors, returned, skill_calls, typed = {}, set(), [], set()

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
            # A tool_result is what proves the call actually came back. Absence
            # means in-flight or crashed, which is NOT completion.
            returned.add(b.get("tool_use_id"))
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
    # Credit COMPLETION, not invocation: the call must have RETURNED and not
    # errored. Checking only `not errors[id]` counted a launched-but-never-
    # returned Skill as satisfied, so a crashed or in-flight checkpoint opened
    # the gate.
    return any(n == step and tid in returned and not errors.get(tid)
               for tid, n in skill_calls)

missing = [s for s in REQUIRED if not satisfied(s)]

# plan-review is ADVISORY, never blocking. Recording its waiver requires editing
# task-context.md, which plan mode hard-denies — so a genuinely below-the-bar
# plan could not satisfy a blocking check by any means except exhausting the
# escape hatch. It is surfaced in the denial text when absent, and the
# /task-done Checkpoint gate still requires it to be resolved before shipping.
advisory = []
if not satisfied(CONDITIONAL):
    # Accept an explicit waiver in the charter for the below-the-bar case.
    #
    # The waiver must be the plan-review LINE inside the ## Checkpoints SECTION.
    # An earlier version searched the whole file for any `- [~] waived:`, which
    # meant a waived Acceptance item — or a waiver of a different checkpoint —
    # silently satisfied plan-review. Caught by /cross-review on this very
    # branch and reproduced before fixing. This scoping now matches
    # hook-destructive-guard.sh, which reads the same section; the two parsers
    # must agree on waiver syntax.
    try:
        tc = open(os.environ["TASK_CONTEXT"], errors="ignore").read()
    except Exception:
        tc = ""
    # One unambiguous shape: a [~] line, inside ## Checkpoints, naming
    # plan-review. Both the template and hook-destructive-guard.sh use it.
    sec = re.search(r"^## Checkpoints[ \t]*$(.*?)(?=^## |\Z)", tc, re.M | re.S)
    body = sec.group(1) if sec else ""
    if not re.search(r"^\s*-\s*\[~\][^\n]*plan-review", body, re.M | re.I):
        advisory.append(CONDITIONAL)

# Only REQUIRED steps gate. Advisory steps ride along in the message so they are
# visible, but never on their own cause a denial.
# Explicit sentinel, never whitespace: an invisible TAB delimiter breaks
# silently if anything ever normalizes tabs to spaces, and the failure mode is
# an advisory-only gap starting to DENY.
parts = " ".join(missing)
if advisory:
    # No leading separator when nothing is required-missing: the shell splits on
    # the sentinel, and a lone space would read as a non-empty required list.
    parts = (parts + " " if parts else "") + "ADVISORY: " + " ".join(advisory)
print(parts)
' 2>/dev/null)" || allow_through

REQUIRED_MISSING="${MISSING%%ADVISORY:*}"
case "$MISSING" in
  *ADVISORY:*) ADVISORY_MISSING="${MISSING#*ADVISORY:}" ;;
  *)           ADVISORY_MISSING="" ;;
esac

# Advisory-only gaps never deny.
[ -n "$REQUIRED_MISSING" ] || { rm -f "$COUNTER" 2>/dev/null || true; allow_through; }

# --- deny --------------------------------------------------------------------
mkdir -p "$AUDIT_DIR" 2>/dev/null || true
# Self-gitignoring, same as hook-destructive-guard.sh:213. Without it the
# counter is an untracked file in any repo that does not already ignore
# .claude/audit/, and `git add -A` sweeps session ids into a commit.
[ -f "$AUDIT_DIR/.gitignore" ] || echo '*' > "$AUDIT_DIR/.gitignore" 2>/dev/null || true
echo "$SESSION_ID:$((DENIALS + 1))" > "$COUNTER" 2>/dev/null || true

REMAINING=$((GATE_MAX_DENIALS - DENIALS - 1))
MISSING="$REQUIRED_MISSING" ADVISORY="$ADVISORY_MISSING" REMAINING="$REMAINING" python3 -c '
import json, os
missing = os.environ["MISSING"].split()
names = {
    "clarify": "/clarify — ask the user the questions that close the gaps",
    "anythingelse": "/anythingelse — the wildcard checkpoint",
    "plan-review": "/plan-review — foreign-model review (or record `- [~] plan-review: waived — below complexity bar` under ## Checkpoints)",
}
lines = "\n".join("  - " + names.get(m, m) for m in missing)
adv = [a for a in os.environ.get("ADVISORY", "").split() if a]
if adv:
    lines += "\n\nAlso not run (advisory — not blocking this approval):\n" + \
             "\n".join("  - " + names.get(a, a) for a in adv)
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
