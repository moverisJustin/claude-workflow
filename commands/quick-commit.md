---
description: Fast commit - stage all changes and commit with a descriptive message (no push, no PR)
---

# Changes
!`git status --short`
!`git diff --stat`
!`git branch --show-current 2>/dev/null`
!`git rev-list --count HEAD 2>/dev/null`

---

## Branch Check

If on main/master AND more than 5 commits exist, warn:
"You're on main. Consider `/task-branch <name>` first. Continue anyway?"
Wait for confirmation before proceeding.

## Quick Commit

Based on the changes:

1. **Stage all changes**
   ```bash
   git add -A
   ```

2. **Commit with conventional commit format**
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `docs:` - Documentation
   - `chore:` - Maintenance
   - `refactor:` - Restructuring
   - `test:` - Tests

Keep message under 72 characters. Be descriptive but concise.

**DO NOT push or create PR** - just commit locally.

Report the commit SHA when done.
