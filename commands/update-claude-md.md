---
description: Update CLAUDE.md with learnings from recent work - mistakes to avoid, new patterns, updated commands
---

# Context Gathering

## Recent Git History
!`git log --oneline -10; true`

## Current CLAUDE.md
!`cat CLAUDE.md 2>/dev/null; true`

## Recent Changes
!`git diff HEAD~3 --stat; true`

---

## Learning Review

Analyze recent work and conversation to identify:

### 1. Mistakes Made
Things that went wrong that should be documented:
- Bugs introduced and how they were fixed
- Wrong approaches that wasted time
- Misunderstandings about the codebase

### 2. New Patterns Discovered
Patterns or conventions that should be followed:
- Code patterns that work well
- Testing approaches
- File organization

### 3. Commands/Scripts Updated
New or changed development commands:
- Build commands
- Test commands
- Deployment scripts

### 4. Architecture Decisions
Significant decisions that affect future work:
- Why something was built a certain way
- Trade-offs that were made

---

## Update CLAUDE.md

Based on the analysis, update CLAUDE.md with new learnings.

**Format for new entries:**

```markdown
## Mistakes to Avoid

### [Date] - [Brief Title]
**What happened**: [Description]
**Why it's wrong**: [Explanation]
**Do this instead**: [Correct approach]
```

```markdown
## Learned Patterns

### [Pattern Name]
**When to use**: [Context]
**How to implement**: [Brief guide]
**Example**: [Code snippet if helpful]
```

If CLAUDE.md doesn't exist, create it with the standard template structure.

Report what was added/updated.
