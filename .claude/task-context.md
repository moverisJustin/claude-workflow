# Task Context — feature/phase1-retire-native-superseded

## Objective
Boris v3 upgrade, **Phase 1: retire what native Claude Code strictly dominates**
(second PR of the approved plan; Phase 0 = PR #5, merged). Docs updated in the
same commit so nothing mandates deleted machinery.

## Retired (9 commands, 6 agents)
| Was | Native replacement |
|---|---|
| /checkpoint, /rollback, /undo | /rewind (Esc-Esc); `git reset --soft HEAD^` for commits; auto-checkpoint tags for bash destruction |
| /mode + mode-controller agent | Native plan mode / permission modes (harness-enforced) |
| /review-changes + pr-reviewer | /code-review <effort> (--comment, --fix, ultra) |
| /security-scan + security-auditor | /security-review |
| /verify-all, /test-and-fix + verify-app | /verify + new /checks command |
| code-simplifier agent | /simplify |
| audit-logger agent | Working PreToolUse audit hooks (Phase 0) |
| /context | Native /context + statusline |

## Added
- `commands/checks.md`: stack-DETECTED quality gates (no blind npm+pytest
  volleys; includes `ruff format --check`); arms `.claude/audit/verify-gate`
  (self-gitignored dir, root-anchored via `git rev-parse --show-toplevel`).
- `scripts/hook-stop-verify.sh` + Stop hook wiring: blocks turn-end while the
  gate is armed (opt-in per /checks run, never blocks normal turns); escape
  hatch after 3 attempts + 2h staleness disarm so the agent is never trapped.
- `install.sh` Phase 3.5: removes retired files from existing installs.
- git-guardian rewritten slim: push-target/staging verification + branch
  protection + recovery routing table (its checkpoint/undo core is gone).

## Docs updated in lockstep
CLAUDE.md (quick ref, §2, §4, §7, §10), README.md (counts 16→10 agents /
25→17 commands, tables, modes), CHEATSHEET.md ("Native Replacements" table),
boris.md + skills/boris-workflow delegation tables, session-end.md,
task-done.md (the `|| true` verification chain is gone), and the user-global
~/.claude/CLAUDE.md (2 stale references, machine-local, not in this diff).

## Verification
- test-hooks.sh: 34/34 (/bin/bash 3.2) incl. 4 new verify-gate tests
- test-sync-lessons.sh: 15/15; settings.base.json valid; install/uninstall bash -n

## Next phases (plan: ~/.claude/plans/calm-skipping-thunder.md)
2. commands/ → skills/ migration; boris consolidation; CLAUDE.md slimming.
3. Memory hybrid; agent memory for specialists.
4. /ci-loop → /loop; model tiers; permissions overhaul; plugin packaging.
