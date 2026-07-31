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
- Wiring Forge's own rules template in as-is — its silent Task Complete sweep
  collides with `/task-done`. (Upstream:
  https://github.com/ericbrown/forge/blob/main/src/forge/templates/CLAUDE-forge.md)
- Creating any GitHub repo, joining `Moveris/forge-mira`, or pushing team
  context. All testing runs against a local no-remote scratch repo.
- Forge's `saas` backend.

## Acceptance
- [x] `scripts/forge-bridge.sh` is the single point that knows Forge exists;
      every touchpoint no-ops silently when the CLI is absent — smoke-tested
      across all 9 subcommands in a plain repo, every one exit 0
- [x] Publish cadence implemented: forge written+pushed continuously (work
      start, plan approved, plan amended, phase done, contract change,
      deprecation, ready, session end); project repo unchanged at chunk cadence
      — full cadence walk green, incl. the negative case proving independence
- [x] A forge failure warns and continues — never blocks the turn (unreachable
      remote: entry preserved, exit 0, loud warning, backlog drained on retry)
- [x] Teammate content is read as data; a team rule conflicting with a Boris
      rule is surfaced for adoption, never silently obeyed
- [x] `/clarify` turns a real teammate collision into a batched question, and
      stays silent on non-overlapping work — both directions tested
- [x] `scripts/resolve-base-branch.sh` returns `master` for
      `moveris_training_data`, `main` for `mira`, `develop` +
      `{develop,main}` protected for `moveris-verification-ui` — verified
      against the live repos
- [x] All 8 hardcoded `main` references use the resolver; `git-safety.md` and
      `/task-done`'s preflight speak in terms of *protected* branches (plural)
- [x] `test-forge-bridge.sh` (42), `test-resolve-base-branch.sh` (20),
      `test-install.sh` (44), `test-hooks.sh` (43) green; drift 98/100;
      maintenance-check clean

## Assumptions
- [~] accepted: Teammate-authored forge content is surfaced but never obeyed —
      team rule changes are proposed to the user, not auto-adopted. Safe to
      live with because it fails in the conservative direction (a real team
      rule gets surfaced and adopted one turn later, rather than a teammate's
      file silently reconfiguring git behaviour). Deliberately stricter than
      Forge intends; one paragraph in `documentation-channels.md` reverses it.
- [~] accepted: Eric's team may treat the shared tickets/PRs snapshots as
      load-bearing; we don't publish them because Linear and `gh` are
      canonical. Safe because the fix is already available with no code change
      — `forge-bridge.sh publish tickets "..."` passes straight through to
      `forge write`, which accepts that type.
- [x] confirmed: Forge stays on the `local` backend — verified from the
      backend resolver that `local` is the default and `saas` requires an
      explicit `api_key` + `workspace` in `~/.forge/config`, neither of which
      this integration sets or reads.
- [~] accepted: for THIS branch — nothing was published and no repo was
      joined, so the access boundary is not yet live. **Still open for Justin
      before running `forge init`**: `Moveris/forge-mira` is org-private, and
      anyone with access to it sees every contract, plan, and handoff for Mira
      regardless of their access to the Mira code repo. Worth a look if any
      Mira work is client-sensitive. Carried into the PR body deliberately.

## Plan
Full approved plan: `~/.claude/plans/optimized-dreaming-lemon.md`

- [x] 1. Charter + ledger (this file)
- [x] 2. `scripts/resolve-base-branch.sh` + `test-resolve-base-branch.sh`
- [x] 3. `scripts/forge-bridge.sh` + `test-forge-bridge.sh`
- [x] 4. `skills/forge/SKILL.md`
- [x] 5. Rules: `documentation-channels.md` (channel 4 + cadence),
       `git-safety.md` (protected branches)
- [x] 6. Skill touchpoints + the 8 hardcoded `main` refs
- [x] 7. README + CHEATSHEET
- [x] 8. Verification (incl. cadence walk and resolver vs real repos)

## Loops
- **Linear**: MOV-2883 (In Progress) — https://linear.app/moveris/issue/MOV-2883
- **BSpec**: n/a — the durable design record is the ARC spec's sibling concern;
  this change is an integration of an external tool plus a bug fix, and the
  precedence/cadence contract lives in `rules/documentation-channels.md`
  (the rule file IS the durable record here, not a separate spec)
- **Handoff**: none
- **Forge**: n/a — this repo (claude-workflow) has no forge repo; Mira is the
  first consumer of what's built here

## Decisions
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-31 | Forge is transport only; Boris authors | Most of Forge duplicates Boris for a single operator. Only the cross-person axis (contracts, deprecations, ready, in-flight wip/plans) is genuinely new. |
| 2026-07-31 | Forge cadence decoupled from git cadence | Shared repo updated continuously through the day; project repo at meaningful chunks. This decoupling is the whole reason the context can't live in the project repo. |
| 2026-07-31 | Do NOT wire Forge's generated rules pointer in as-is | Its silent Task Complete sweep would run a second closing sequence against `/task-done`. |
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

- All 8 plan steps complete; both commits landed (cc4ce4b, b7f4252)
- Verification: 20 resolver + 42 bridge + 44 installer + 43 hook tests green;
  drift 98/100; maintenance-check clean; installer output grepped not trusted

### In Progress
- PR

### Blocked
- [nothing blocked]

## Notes
Findings from reading the Forge v0.3.7 source. All paths below are in the
UPSTREAM repo (https://github.com/ericbrown/forge), not this one:
- Context repo location: cli line 1091 → `Path.home() / f"forge-{name}"`.
  The project repo only ever receives three wiring files.
- Forge merges (not clobbers) a project's Claude settings: cli lines 99-110
- Collision primitive: `forge.conflict_check` → `find_conflicts()`, keyword
  threshold 3, is-active filter. Upstream only compares wip; we extend to plans.
- `forge write` has NO deprecations target (cli line 671) — the bridge appends
  in the documented format instead
- Local no-remote repo works: the scaffold's commit helper skips push when no
  remote is configured
- Hardcoded `main` sites: `task-branch:40-41`, `task-done:141,180,260-261`,
  `loops:22`, `fix-issue:52`, plus `git-safety.md:3,6` and `task-done:22`
- `install.sh` globs `skills/*/` and `scripts/*.sh` — no installer edit needed
  for new skills/scripts (Phase 4 and Phase 6)
