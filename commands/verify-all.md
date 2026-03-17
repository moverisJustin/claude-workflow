---
description: Run complete verification suite - tests, types, lint, build - and report comprehensive status
---

# Complete Verification Suite

## Test Suite
!`npm test`

## TypeScript
!`npm run typecheck`

## Linting
!`npm run lint`

## Build
!`npm run build`

## Python Checks (if applicable)
!`pytest --tb=short`
!`mypy .`
!`ruff check .`

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
