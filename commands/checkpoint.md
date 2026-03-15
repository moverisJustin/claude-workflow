---
description: Create a named checkpoint for easy rollback. Saves current state with a memorable name.
---

# Create Checkpoint

## Current State
!`git status --short 2>/dev/null`
!`git stash list 2>/dev/null | grep "checkpoint:" | head -5`
!`git tag -l "checkpoint/*" 2>/dev/null | tail -5`

---

## Checkpoint Protocol

### Checkpoint Name
Name: $ARGUMENTS

If no name provided, generate: `checkpoint-$(date +%Y%m%d-%H%M%S)`

### 1. Save Current State

**Stage all changes:**
```bash
git add -A
```

**Create stash checkpoint:**
```bash
git stash push -m "checkpoint:$NAME"
```

**Create tag checkpoint (persistent):**
```bash
git tag -a "checkpoint/$NAME" -m "Checkpoint: $NAME - $(date)"
```

### 2. Checkpoint Types

| Type | Storage | Persistence | Use Case |
|------|---------|-------------|----------|
| Stash | Local stash | Until dropped | Quick saves |
| Tag | Git tags | Until deleted | Important milestones |
| Branch | Git branch | Permanent | Major features |

### 3. Execute

For quick checkpoint (stash):
```bash
git add -A
git stash push -m "checkpoint:$NAME"
echo "📍 Checkpoint created: $NAME"
```

For persistent checkpoint (tag):
```bash
git add -A
git commit -m "checkpoint: $NAME" --allow-empty
git tag "checkpoint/$NAME"
echo "📍 Persistent checkpoint: $NAME"
```

### 4. Report

```
📍 Checkpoint Created

Name: [checkpoint name]
Type: [stash/tag]
Time: [timestamp]
Files included: [count]

Restore with: /rollback [name]
List checkpoints: /checkpoints
```

### 5. Record in Memory Bank

Update `.claude/memory/activeContext.md`:
```markdown
## Checkpoints
- [name] created at [time] - [reason]
```

---

## Usage Examples

**Create named checkpoint:**
```
/checkpoint before-refactor
```

**Create auto-named checkpoint:**
```
/checkpoint
```

**With description:**
```
/checkpoint pre-auth-changes
```

---

## Checkpoint Best Practices

1. **Before major refactors** - Always checkpoint first
2. **After working code** - Save good states
3. **Before risky changes** - Insurance policy
4. **End of session** - Preserve work state
5. **Clear names** - `pre-auth` not `cp1`
