---
name: fix-issue
description: Fetch a GitHub/Linear issue, understand requirements, implement the fix, and create a PR. End-to-end issue resolution.
argument-hint: [issue-id]
disable-model-invocation: true
---

# Fix Issue: $ARGUMENTS

## Fetching Issue Details...

!`gh issue view $ARGUMENTS --json number,title,body,labels,assignees,state`

## Linear Issue (if GitHub issue not found)
If the issue number starts with a project prefix (e.g., PROJ-123), delegate to
the `linear-project-manager` subagent (per
`~/.claude/rules/documentation-channels.md`):
- Fetch the issue details
- Move it to In Progress at start
- Comment + move to In Review when the PR opens (step 7)

## Issue Comments (Context)
!`gh issue view $ARGUMENTS --json comments`

Focus on the most recent comments for context.

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

BASE=$(bash ~/.claude/scripts/resolve-base-branch.sh --base)
git checkout "$BASE" && git pull origin "$BASE"
git checkout -b "issue-$ISSUE_NUM-$SLUG"
```

### 2.5. Initialize Task Context

After creating the branch, initialize `.claude/task-context.md`:

```bash
mkdir -p .claude
# Create task-context.md (charter template from /task-branch) with:
# - Branch name and base SHA
# - Issue number and title (+ why, from the body) as Objective
# - Non-goals from the issue's Out of Scope section (if any)
# - Acceptance ("- [ ]" items) from the issue's acceptance criteria/checkboxes
# - Loops ledger: Linear = this issue (In Progress), BSpec = OPEN, Handoff = none
# - Issue body summary in Notes
git add .claude/task-context.md
git commit -m "chore: initialize task context for issue #$ISSUE_NUM"
```

Pre-populate the charter from the issue: Objective from the title and body,
Non-goals from its Out of Scope section, Acceptance from its acceptance
criteria or checkboxes. This backfill happens ONCE — from here on the charter
is authoritative and syncs one-way, charter → Linear.

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

GitHub issue:
```bash
gh issue comment $ARGUMENTS --body "PR created. Ready for review."
gh issue edit $ARGUMENTS --add-label "in-review"
```

Linear issue: delegate to the `linear-project-manager` subagent — comment the
outcome (summary + PR URL) and move the status to In Review.

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
