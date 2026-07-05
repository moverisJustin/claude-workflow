---
name: ci-loop
description: Push, then watch CI in the BACKGROUND (no blocked turn), parse failures, auto-fix, and iterate until green. Non-blocking CI feedback loop.
argument-hint: [optional PR# or branch]
disable-model-invocation: true
---

# CI Loop

Push and drive CI to green **without blocking the session**. The old version
ran `gh run watch --exit-status` in a foreground command, freezing the whole
turn for the entire CI run (often 10+ minutes). This version watches in the
background, so you stay free to work and are re-invoked when CI finishes.

## Pre-flight

!`git status --short`
!`git branch --show-current`

Config: max 5 fix iterations; auto-fix lint/format/types; tests and E2E need
analysis (never blindly "fix" a failing test).

## 1. Push

```bash
BRANCH=$(git branch --show-current)
git push origin "$BRANCH"
```

## 2. Watch CI in the background (do NOT block the turn)

Get the run id, then watch it as a **background task** — run this Bash with
`run_in_background: true` so the harness re-invokes you on completion instead of
freezing the session:

```bash
RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

- **Background task exits 0** → CI is green. Go to step 5 (success).
- **Background task exits non-zero** → CI failed. Go to step 3.

While it runs, you can keep working on other things; you'll be notified when it
exits. (For a persistent "keep this branch green" watcher across many pushes,
`/loop` is the right tool; for a single push→green cycle, the background task
above is simpler and event-driven.)

## 3. Parse the failure

```bash
gh run view "$RUN_ID" --log-failed > /tmp/ci-failure-$RUN_ID.log
```

Classify (github-actions primary; the same parse applies to gitlab/circle/azure
logs — detect from `.github/workflows`, `.gitlab-ci.yml`, `.circleci/`, etc.):

| Signal | Category | Auto-fix? |
|---|---|---|
| `error TS####:` | TypeScript | yes — fix the type at the location |
| `ruff`/`eslint` `error` | Lint | yes — run the fixer, then re-check |
| format check failed | Format | yes — run the formatter |
| `FAIL` / `✕` / assertion | Test | analyze — is it the test or the code? |
| `Module not found` / build error | Build | usually deps/config — investigate |
| timeout / flaky / missing secret | Infra/E2E | do NOT auto-fix — report |

## 4. Fix, commit, re-watch

Apply the fix (lint/format via the project's fixer; types/tests by editing the
root cause — run `/checks` locally first to confirm before pushing), then:

```bash
git add -A
git commit -m "fix: address CI failure (ci-loop iteration N)"
git push origin "$BRANCH"
```

Re-watch from step 2 (again in the background). Increment N. **Circuit breaker:
stop after 5 iterations** and report — repeated failure means the auto-fix
isn't converging.

## 5. Report

**Green:**
```
CI Loop: green
Iterations: N | Run: <url>
Fixes: [what was changed each iteration, or "none — passed first try"]
```

**Stuck (circuit breaker or non-auto-fixable):**
```
CI Loop: manual fix required
Iterations: N | Still failing: <job/step>
Category: [test/E2E/infra/config/secret]
Log: <url>
Why it can't auto-fix: [flaky state, external dep, missing secret, ...]
Suggested next steps: [1-3 concrete actions; e.g. run the failing job locally]
```

Never claim green without the background watch actually exiting 0. If tests were
skipped or a job was cancelled, say so — don't report a cancelled run as passing.
