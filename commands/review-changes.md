---
description: Review uncommitted changes for quality, bugs, and improvements before committing
---

# Current Changes

## Status
!`git status --short; true`

## Diff
!`git diff; true`

## Staged Changes
!`git diff --cached; true`

---

## Code Review

Analyze the changes above and provide feedback:

### 1. Summary
Brief overview of what these changes accomplish.

### 2. Quality Assessment

**Correctness**
- Any obvious bugs or logic errors?
- Edge cases handled?
- Error handling appropriate?

**Security**
- Any security concerns?
- Input validation present?
- No hardcoded secrets?

**Readability**
- Code is clear and understandable?
- Good naming?
- Appropriate comments?

**Performance**
- Any performance concerns?
- Unnecessary operations?

### 3. Improvements
Specific suggestions for making the code better:
- Line X: [suggestion]
- Line Y: [suggestion]

### 4. Verification Needed
- What tests should be run?
- Any manual testing required?

### 5. Verdict

- [ ] ✅ **Ready to commit** - Changes look good
- [ ] ⚠️ **Minor issues** - Consider fixing before commit
- [ ] ❌ **Needs work** - Should fix before committing

If ready: suggest `/commit-push-pr`
If needs work: list specific items to address
