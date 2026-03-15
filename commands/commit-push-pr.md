---
description: Complete git workflow - stage changes, commit with conventional message, push to remote, and create a pull request
---

# Git Context
!`git status --short`
!`git branch --show-current`
!`git log -3 --oneline`
!`git diff --stat`

---

## 0. Branch Check

!`git branch --show-current 2>/dev/null`
!`git rev-list --count HEAD 2>/dev/null || echo "0"`

**If on main/master:**
- If fewer than 5 commits: this is initial build phase -- proceed with a note.
- If 5+ commits: **WARN** the user:
  ```
  WARNING: You are committing directly to main.
  Recommended: Create a task branch first with /task-branch <name>
  Continue on main anyway? (Only for hotfixes or initial setup)
  ```
  Wait for user confirmation before proceeding on main.

---

Based on the changes above, execute the full git workflow:

## 1. Stage Changes
Stage all modified files appropriately.

## 2. Commit
Create a commit with a **conventional commit** message:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Formatting, no code change
- `refactor:` - Code change that neither fixes nor adds
- `perf:` - Performance improvement
- `test:` - Adding tests
- `chore:` - Maintenance, deps, config

Format: `type(scope): description`

Keep the first line under 72 characters. Add a body if the change needs explanation.

## 2.5. Verify Push Target
Before pushing, always verify the remote:
!`git remote -v`

Confirm the remote URL matches the intended repository before pushing. If unsure, ask the user.

## 3. Push
Push to the remote repository. Create the remote branch if needed.

## 4. Create PR
Use `gh pr create` to open a pull request with:
- Clear, descriptive title
- Body explaining what changed and why
- Link to related issues if applicable

```bash
gh pr create --title "type(scope): description" --body "## Summary
- What was done
- Why it was done

## Testing
- How it was tested

## Related
- Closes #123 (if applicable)"
```

If there are no changes to commit, inform the user and suggest next steps.
