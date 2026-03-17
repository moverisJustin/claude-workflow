---
description: Rollback to a previous checkpoint or N commits back. Restore saved state safely.
---

# Rollback

## Available Checkpoints

### Stash Checkpoints
!`git stash list`

### Tag Checkpoints
!`git tag -l "checkpoint/*"`

### Recent Commits
!`git log --oneline -10`

---

## Rollback Target
Target: $ARGUMENTS

---

## Rollback Protocol

### 1. Identify Target

**If numeric (e.g., `3`):**
Rollback 3 commits
```bash
git reset --soft HEAD~3
```

**If checkpoint name (e.g., `pre-refactor`):**
Find in stash or tags
```bash
# Check stash
git stash list | grep "checkpoint:$NAME"

# Check tags
git tag -l "checkpoint/$NAME"
```

### 2. Safety Checks

Before rollback:
- [ ] Current work saved? (stash or commit)
- [ ] Not on protected branch?
- [ ] Understand what will be lost?

```bash
# Show what will be affected
git log --oneline HEAD~$N..HEAD  # For numeric
git diff checkpoint/$NAME HEAD   # For named
```

### 3. Execute Rollback

**From Stash Checkpoint:**
```bash
git stash apply stash@{N}  # Where N is stash index
# or
git stash pop stash@{N}    # Apply and remove
```

**From Tag Checkpoint:**
```bash
# Soft rollback (keep changes)
git reset --soft checkpoint/$NAME

# Hard rollback (discard changes)
git checkout checkpoint/$NAME
git checkout -b restored-from-$NAME
```

**From Commit Count:**
```bash
# Soft (keep changes staged)
git reset --soft HEAD~$N

# Mixed (keep changes unstaged)
git reset HEAD~$N

# Hard (discard changes) ⚠️
git reset --hard HEAD~$N
```

### 4. Rollback Options

| Option | Command | Keeps Changes | Use When |
|--------|---------|---------------|----------|
| Soft | `--soft` | Staged | Review before discard |
| Mixed | (default) | Unstaged | Selective re-commit |
| Hard | `--hard` | No | Full revert |

### 5. Report

```
↩️ Rollback Complete

Target: [checkpoint/commit]
Method: [soft/mixed/hard]
Commits undone: [N]
Files affected: [count]

Current state: [branch and status]

To undo rollback: git reflog
```

### 6. Post-Rollback

- Update Memory Bank with rollback info
- Log in audit trail
- Notify about any lost work

---

## Usage Examples

**Rollback 2 commits:**
```
/rollback 2
```

**Restore checkpoint:**
```
/rollback pre-refactor
```

**Rollback to specific commit:**
```
/rollback abc1234
```

---

## Emergency Recovery

If rollback goes wrong:
```bash
# View all history including undone
git reflog

# Restore to any previous state
git reset --hard HEAD@{N}
```

**Git reflog is your safety net** - nothing is truly lost until garbage collected.
