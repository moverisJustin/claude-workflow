---
description: Push code, wait for CI, parse failures, auto-fix, and iterate until green. Automated CI feedback loop.
---

# CI Loop

## Pre-flight Check

!`git status --short; true`
!`git branch --show-current; true`
!`gh run list --limit 3 2>/dev/null; true`

---

## CI Loop Protocol

### Configuration
- **Max Iterations**: 5
- **Poll Interval**: 30 seconds
- **Auto-fix**: Lint, Types (Tests require confirmation)

### 1. Initial Push

```bash
BRANCH=$(git branch --show-current)
echo "🚀 Pushing to $BRANCH..."
git push origin "$BRANCH"
```

### 2. Wait for CI

```bash
echo "⏳ Waiting for CI..."

# Get latest run
RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId -q '.[0].databaseId')

# Watch and wait
gh run watch "$RUN_ID" --exit-status
```

### 3. Parse Results

If CI fails:

```bash
# Get failure logs
gh run view "$RUN_ID" --log-failed > /tmp/ci-failure.log

# Parse for actionable errors
echo "=== TypeScript Errors ==="
grep -E "error TS[0-9]+:" /tmp/ci-failure.log | head -10

echo "=== Test Failures ==="
grep -A 3 "FAIL\|✕" /tmp/ci-failure.log | head -20

echo "=== Lint Errors ==="
grep -E "error\s+" /tmp/ci-failure.log | head -10

echo "=== Build Errors ==="
grep -E "Error:|BUILD FAILED" /tmp/ci-failure.log | head -10
```

### 4. Auto-Fix Attempt

**Lint Errors** (auto-fixable):
```bash
npm run lint:fix
```

**Type Errors** (analyze and fix):
- Parse error location
- Determine fix
- Apply carefully

**Test Failures** (requires analysis):
- Understand what failed
- Determine if test or code issue
- Fix accordingly

**Build Errors** (investigate):
- Usually dependency or config
- May need manual intervention

### 5. Commit Fixes

```bash
git add -A
git commit -m "fix: address CI failures

Auto-fixes applied:
- [List what was fixed]

🤖 CI Loop iteration $ITERATION"
```

### 6. Iterate

Repeat steps 1-5 until:
- ✅ All checks pass, or
- ⚠️ Max iterations reached, or
- ❌ Non-auto-fixable issue found

---

## Iteration Tracking

| Iteration | Status | Fixes Applied |
|-----------|--------|---------------|
| 1 | [Pass/Fail] | [What was fixed] |
| 2 | [Pass/Fail] | [What was fixed] |
| ... | ... | ... |

---

## Circuit Breaker

After 5 iterations without success:

```
⚠️ CI Loop: Maximum iterations reached

Status: Still failing after 5 attempts
Blocker: [What's still failing]

This issue requires manual intervention.

Suggestions:
1. [Specific suggestion based on failure]
2. Run locally to debug
3. Check CI configuration
```

---

## Output Format

### Success
```markdown
## ✅ CI Loop Complete

### Summary
- **Iterations**: 2
- **Duration**: 5m 30s
- **Final Status**: All checks passing

### Fixes Applied
#### Iteration 1
- ESLint: Fixed 3 unused variable warnings
- Prettier: Formatted 2 files

#### Iteration 2
- TypeScript: Added missing type annotation

### CI Run
- **Run ID**: 12345678
- **Link**: [URL]

### Ready for Review
All checks are green. PR is ready for review.
```

### Failure
```markdown
## ❌ CI Loop: Manual Fix Required

### Summary
- **Iterations**: 5 (max reached)
- **Status**: Still failing

### Blocker
E2E test failure in `checkout.spec.ts`:
```
Timeout waiting for element [data-testid="submit-btn"]
```

### Analysis
This appears to be a flaky test or timing issue.
Cannot auto-fix - requires investigation.

### Suggestions
1. Check if selector changed
2. Add explicit wait for element
3. Run E2E locally: `npm run test:e2e -- --headed`

### CI Logs
[Link to failed run]
```

---

## Manual Intervention Points

Some issues cannot be auto-fixed:
- E2E test failures (complex state)
- Integration test failures (external deps)
- Configuration errors
- Missing secrets/env vars
- Flaky tests

When encountered, report clearly and provide debugging suggestions.
