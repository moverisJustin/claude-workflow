---
description: Show context window usage, Memory Bank status, and recommendations for context management
---

# Context Status

## Memory Bank Status

### Files Present
!`ls -la .claude/memory/`

### File Sizes
!`wc -l .claude/memory/*.md`

### Last Updated
!`ls -lt .claude/memory/*.md`

## Session History Size
!`wc -l .claude/memory/sessionHistory.md`

## Git Context

### Uncommitted Changes
!`git status --short`

### Recent Commits
!`git log --oneline -5`

### Branch
!`git branch --show-current`

---

## Context Management Guide

### Understanding Context Usage

Claude's context window includes:
- System prompt and tools
- Conversation history
- Files read this session
- Memory Bank content
- CLAUDE.md content

### Signs of High Context Usage

Watch for:
- Slower responses
- Forgetting earlier conversation
- Repetitive file re-reading
- Contradicting previous statements

### Recommended Actions

**If context is high (>75%):**

1. **Compact manually**
   ```
   /compact
   ```
   Summarizes conversation history to free space.

2. **Save session state**
   ```
   /session-end
   ```
   Preserves context to Memory Bank before compaction.

3. **Use subagents**
   Delegate research tasks to agents with isolated context.

**Proactive context management:**

1. **Keep Memory Bank lean**
   - Archive old session history (>30 days)
   - Summarize verbose entries
   - Remove outdated context

2. **Use .claudeignore**
   ```
   # .claudeignore
   node_modules/
   dist/
   *.log
   *.lock
   ```
   Prevents large files from being read.

3. **Scope sessions**
   Work on one subsystem per session when possible.

4. **Clear file focus**
   Tell Claude which files are relevant upfront.

---

## Memory Bank Health Check

### Optimal State
- projectContext.md: < 500 lines
- activeContext.md: < 100 lines
- progress.md: < 200 lines
- decisionLog.md: Archive entries > 6 months
- conventions.md: < 300 lines
- sessionHistory.md: < 1000 lines (archive older)

### Maintenance Commands

**Archive old history:**
```bash
# Move old sessions to archive
mkdir -p .claude/memory/archive
head -n -500 .claude/memory/sessionHistory.md > .claude/memory/archive/sessions-$(date +%Y%m).md
tail -500 .claude/memory/sessionHistory.md > .claude/memory/sessionHistory.tmp
mv .claude/memory/sessionHistory.tmp .claude/memory/sessionHistory.md
```

**Clean up progress:**
```bash
# Remove completed items older than 30 days
# Manual review recommended
```

---

## Context Optimization Tips

### For Large Codebases

1. **Progressive disclosure**
   - Don't read entire files upfront
   - Read sections as needed
   - Use grep/search first

2. **Summarize, don't copy**
   - Ask for summaries of large files
   - Keep relevant excerpts only

3. **Batch file operations**
   - Read related files together
   - Reduce context switches

### For Long Sessions

1. **Session checkpoints**
   - Run `/session-end` periodically
   - Start fresh with `/session-start`

2. **Scope to subsystems**
   - One feature per session
   - Clear boundaries

3. **Document as you go**
   - Update Memory Bank throughout
   - Not just at session end

---

## Output Format

```markdown
## 📊 Context Status

### Memory Bank
| File | Lines | Last Updated |
|------|-------|--------------|
| projectContext.md | 45 | 2 days ago |
| activeContext.md | 23 | Today |
| progress.md | 67 | Today |
| sessionHistory.md | 234 | Today |

### Health
- ✅ All files within size limits
- ⚠️ sessionHistory.md approaching limit (archive recommended)

### Recommendations
1. [If any maintenance needed]

### Quick Actions
- Archive old history: `[command]`
- Start fresh session: `/session-end` then `/session-start`
- Manual compact: `/compact`
```
