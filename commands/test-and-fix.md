---
description: Run test suite, analyze failures, fix issues, and iterate until all tests pass
---

# Running Verification Suite

!`npm test`
!`npm run typecheck`
!`npm run lint`

## Python Tests
!`pytest --tb=short`

---

## Analysis & Action

Based on the results above:

### If All Checks Pass
Report success:
- Tests: X passing
- Types: Clean
- Lint: Clean

Suggest next steps: `/commit-push-pr` or `/review-changes`

### If Any Checks Fail

**Priority Order:**
1. **TypeScript errors** - Fix first (blocks everything)
2. **Test failures** - Fix next (correctness matters)
3. **Lint errors** - Fix last (style issues)

**Process:**
1. Analyze the specific failures
2. Identify root cause (don't just fix symptoms)
3. Make targeted fixes
4. Re-run the failing checks
5. Iterate until all pass

**Guidelines:**
- Don't weaken tests to make them pass
- Don't disable linting rules
- Fix the actual problem, not the error message
- If a test is genuinely wrong, fix the test with explanation

**After each fix:**
```bash
npm test
npm run typecheck
npm run lint
```

Continue iterating until all checks pass, then report final status.
