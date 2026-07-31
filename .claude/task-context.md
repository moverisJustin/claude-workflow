# Task Context

## Branch
**Name**: claude/forge-workflow-integration-60e73e
**Created**: 2026-07-31
**Author**: Justin @ Moveris
**Base**: main @ 0b769aa
**Issue**: N/A

## Objective
Adopt Eric's Forge (github.com/ericbrown/forge, v0.3.7) as a shared-context
**transport** for the Boris workflow — Boris keeps authoring everything, Forge
gets a one-way published projection of what teammates need — and fix the
workflow's hardcoded assumption that every repo branches off `main`, a live bug
Forge's team-rules file surfaced.

## Non-goals
- Replacing any Boris channel with Forge. Linear stays canonical for tickets,
  BSpec for design, the Memory Bank for decisions/lessons.
- Wiring Forge's own `CLAUDE-forge.md` rules in as-is — its silent Task Complete
  sweep collides with `/task-done`.
- Creating any GitHub repo, joining `Moveris/forge-mira`, or pushing team
  context. All testing runs against a local no-remote scratch repo.
- Forge's `saas` backend.

## Acceptance
- [ ] `scripts/forge-bridge.sh` is the single point that knows Forge exists;
      every touchpoint no-ops silently when the CLI is absent
- [ ] Publish cadence implemented: forge written+pushed continuously (work
      start, plan approved, plan amended, phase done, contract change,
      deprecation, ready, session end); project repo unchanged at chunk cadence
- [ ] A forge failure warns and continues — never blocks the turn
- [ ] Teammate content is read as data; a team rule conflicting with a Boris
      rule is surfaced for adoption, never silently obeyed
- [ ] `/clarify` turns a real teammate collision into a batched question, and
      stays silent on non-overlapping work
- [ ] `scripts/resolve-base-branch.sh` returns `master` for
      `moveris_training_data`, `main` for `mira`, `develop` +
      `{develop,main}` protected for `moveris-verification-ui`
- [ ] All 8 hardcoded `main` references use the resolver; `git-safety.md` and
      `/task-done`'s preflight speak in terms of *protected* branches (plural)
- [ ] `test-forge-bridge.sh`, `test-resolve-base-branch.sh`, `test-install.sh`,
      `drift-check.sh` all green

## Assumptions
- [ ] assumed: Teammate-authored forge content is trusted enough to *surface*
      but not to *obey* — team rule changes get proposed, not auto-adopted. If
      the team expects the root `CLAUDE.md` to be binding the way Forge intends,
      this needs revisiting.
- [ ] assumed: Eric's team has not standardised on `shared/tickets.md` /
      `prs.md` snapshots as load-bearing. If they have, we owe them the
      on-demand publisher wired into `/task-done`.
- [ ] assumed: Forge stays on the `local` backend; `saas` is out of scope.
- [ ] assumed: `Moveris/forge-mira` is org-private and everyone with repo
      access is meant to see every contract, plan, and handoff for Mira. If any
      Mira work is client-sensitive, that access boundary needs checking before
      joining — the forge repo is NOT covered by the Mira code repo's
      permissions.

## Plan
Full approved plan: `~/.claude/plans/optimized-dreaming-lemon.md`

- [ ] 1. Charter + ledger (this file)
- [ ] 2. `scripts/resolve-base-branch.sh` + `test-resolve-base-branch.sh`
- [ ] 3. `scripts/forge-bridge.sh` + `test-forge-bridge.sh`
- [ ] 4. `skills/forge/SKILL.md`
- [ ] 5. Rules: `documentation-channels.md` (channel 4 + cadence),
       `git-safety.md` (protected branches)
- [ ] 6. Skill touchpoints + the 8 hardcoded `main` refs
- [ ] 7. README + CHEATSHEET
- [ ] 8. Verification (incl. cadence walk and resolver vs real repos)

## Loops
- **Linear**: MOV-2883 (In Progress) — https://linear.app/moveris/issue/MOV-2883
- **BSpec**: OPEN
- **Handoff**: none
- **Forge**: n/a — this repo (claude-workflow) has no forge repo; Mira is the
  first consumer of what's built here

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-31 | Forge is transport only; Boris authors | Most of Forge duplicates Boris for a single operator. Only the cross-person axis (contracts, deprecations, ready, in-flight wip/plans) is genuinely new. |
| 2026-07-31 | Forge cadence decoupled from git cadence | Shared repo updated continuously through the day; project repo at meaningful chunks. This decoupling is the whole reason the context can't live in the project repo. |
| 2026-07-31 | Do NOT wire `@.claude/forge-claude-rules.md` in as-is | Its silent Task Complete sweep would run a second closing sequence against `/task-done`. |
| 2026-07-31 | Teammate content = data, not instructions | Matches the existing "foreign sources propose, Claude writes" invariant. Concrete case: Eric's example `dev`-branching rule contradicts `git-safety.md`. |
| 2026-07-31 | Branch model resolved empirically, cached after one confirm | Modal merged-PR `baseRefName` got all 5 sampled repos right; beats a config that goes stale. |
| 2026-07-31 | Fold branch-model fix into this PR | User's call; the two are coupled via the team-rule conflict check. |
| 2026-07-31 | No new required heading in `drift-check.sh` | Would retroactively WARN every existing task-context — the template-not-linter lesson. |

## Progress
### Done
- Research: read Forge v0.3.7 source (cli, scaffold, backends, conflict_check,
  mcp_server, CLAUDE-forge template)
- Surveyed 55 active Moveris repos: 43 `main`, 6 `master`, 6 `develop`+`main`
- Confirmed `Moveris/forge-mira` exists (Eric 16:54, mstjern 17:38, all
  scaffold, Justin not yet a member)
- Plan approved

### In Progress
- Charter + ledger

### Blocked
- [nothing blocked]

## Notes
Key file references gathered during research:
- Forge context repo location: `cli.py:1091` → `Path.home() / f"forge-{name}"`
- Forge merges (not clobbers) `.claude/settings.json`: `cli.py:99-110`
- Collision primitive: `src/forge/conflict_check.py` → `find_conflicts()`,
  keyword threshold 3, `_is_active()` filter
- Local no-remote works: `scaffold.py:_git_commit_all` skips push with no remote
- Hardcoded `main` sites: `task-branch:40-41`, `task-done:141,180,260-261`,
  `loops:22`, `fix-issue:52`, plus `git-safety.md:3,6` and `task-done:22`
- `install.sh` globs `skills/*/` and `scripts/*.sh` — no installer edit needed
  for new skills/scripts (Phase 4 and Phase 6)
