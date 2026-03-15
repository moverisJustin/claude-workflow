---
description: Fetch a GitHub/Linear issue, understand requirements, implement the fix, and create a PR. End-to-end issue resolution.
---

# Fix Issue: $ARGUMENTS

## Fetching Issue Details...

!`gh issue view $ARGUMENTS --json number,title,body,labels,assignees,state 2>/dev/null`

## Linear Issue (if GitHub issue not found)
If the issue number starts with a project prefix (e.g., MOV-123), use Linear MCP tools instead:
- Use `mcp__claude_ai_Linear__get_issue` to fetch issue details
- Use `mcp__claude_ai_Linear__update_issue` to update status
- Use `mcp__claude_ai_Linear__create_comment` to add comments

## Issue Comments (Context)
!`gh issue view $ARGUMENTS --json comments -q '.comments[-3:] | .[].body' 2>/dev/null | head -30`

---

## Issue Resolution Protocol

### 1. Parse Issue

Extract from the issue:

**Type** (from labels):
- `bug` - Something broken
- `feature` - New functionality
- `enhancement` - Improve existing
- `documentation` - Docs only

**Acceptance Criteria**:
- Look for checkboxes
- Look for "should" statements
- Look for code examples

### 2. Create Branch

```bash
ISSUE_NUM=$ARGUMENTS
SLUG=$(gh issue view $ISSUE_NUM --json title -q '.title' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-40)

git checkout main && git pull origin main
git checkout -b "issue-$ISSUE_NUM-$SLUG"
```

### 2.5. Initialize Task Context

After creating the branch, initialize `.claude/task-context.md`:

```bash
mkdir -p .claude
# Create task-context.md with:
# - Branch name and base SHA
# - Issue number and title as Objective
# - Acceptance criteria from issue as Plan items
# - Issue body summary in Notes
git add .claude/task-context.md
git commit -m "chore: initialize task context for issue #$ISSUE_NUM"
```

Pre-populate the Objective from the issue title and the Plan from any acceptance criteria or checkboxes found in the issue body.

### 3. Plan Implementation

Create a plan before coding:
- What's the root cause (for bugs)?
- What files need to change?
- What tests are needed?
- Any risks or edge cases?

**Get user approval on plan before proceeding.**

### 4. Implement

- Make changes incrementally
- Follow existing code patterns
- Add tests for new code
- Update documentation if needed

### 5. Verify

```bash
npm test
npm run typecheck
npm run lint
npm run build
```

All checks must pass.

### 6. Commit & PR

```bash
git add -A
git commit -m "fix: [description]

Fixes #$ARGUMENTS"

git push -u origin HEAD

gh pr create \
  --title "Fix #$ARGUMENTS: [title]" \
  --body "## Summary
Fixes #$ARGUMENTS

## Changes
- [What changed]

## Testing
- [How tested]"
```

### 7. Update Issue

```bash
gh issue comment $ARGUMENTS --body "PR created. Ready for review."
gh issue edit $ARGUMENTS --add-label "in-review"
```

---

## Output Format

```markdown
## Issue #[num] Complete

**Title**: [title]
**Type**: [bug/feature]
**Branch**: issue-[num]-[slug]

### Changes Made
- [Description]

### Verification
- Tests pass
- Types check
- Lint clean

### PR Created
#[PR] - [title]
```

---

## No Issue Number?

List open issues:
```bash
gh issue list --state open --limit 10
```

Search issues:
```bash
gh issue list --search "keyword"
```
