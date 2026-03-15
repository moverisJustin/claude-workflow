---
description: Run complete verification suite - tests, types, lint, build - and report comprehensive status
---

# Complete Verification Suite

## Test Suite
!`npm test 2>&1 | tail -20 || echo "TESTS: CHECK OUTPUT ABOVE"`

## TypeScript
!`npm run typecheck 2>&1 || echo "TYPECHECK: FAILED"`

## Linting
!`npm run lint 2>&1 | tail -10 || echo "LINT: FAILED"`

## Build
!`npm run build 2>&1 | tail -10 || echo "BUILD: FAILED"`

## Python Checks (if applicable)
!`pytest --tb=short 2>&1 | tail -20 || echo "No pytest"`
!`mypy . 2>&1 | tail -10 || echo "No mypy"`
!`ruff check . 2>&1 | tail -10 || echo "No ruff"`

---

## Verification Report

Summarize results in this format:

| Check | Status | Details |
|-------|--------|---------|
| Tests | Pass/Fail | X passing, Y failing |
| TypeScript | Pass/Fail | X errors |
| Lint | Pass/Fail | X warnings, Y errors |
| Build | Pass/Fail | Success / Failed at... |
| Pytest | Pass/Fail/N/A | X passing, Y failing |
| Mypy | Pass/Fail/N/A | X errors |
| Ruff | Pass/Fail/N/A | X warnings, Y errors |

## Overall Status

**Ready to commit?**
- [ ] All checks pass - safe to commit
- [ ] Warnings only - consider fixing
- [ ] Failures - must fix before commit

## Recommended Actions

If failures exist, list them in priority order with suggested fixes.

If all pass, suggest: "Ready for `/commit-push-pr`"
