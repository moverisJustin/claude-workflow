---
description: Fast commit - stage all changes and commit with a descriptive message (no push, no PR)
---

# Changes
!`git status --short`
!`git diff --stat`

---

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
