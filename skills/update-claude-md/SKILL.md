---
name: update-claude-md
description: Update CLAUDE.md with learnings from recent work - mistakes to avoid, new patterns, updated commands
---

# Context Gathering

## Recent Git History
!`git log --oneline -10`

## Current CLAUDE.md
Read `CLAUDE.md` using the Read tool.

## Recent Changes
!`git diff HEAD~3 --stat`

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

## Write the Learnings — pick the right destination

Lessons no longer live inside CLAUDE.md (Boris v3 keeps it slim). Route each
learning to where it loads correctly:

| Learning type | Destination |
|---|---|
| Project-specific (repo quirks, local tooling, this codebase's conventions) | `.claude/memory/conventions.md` (project Memory Bank) |
| Universal (workflow patterns, cross-project pitfalls) | `~/.claude/rules/learned-patterns.md` under `# Learned Patterns` |
| Always-true project facts (build commands, layout) | the project's `CLAUDE.md` — keep it under ~150 lines |

**Lesson format** (heading-based — dedup and sync key on the `### ` title):

```markdown
### [Short imperative title]
[What happened, why it's wrong, and the correct approach — 2-5 lines.
Include the concrete trigger/error so future sessions recognize it.]
```

Publishing a universal lesson to the public workflow repo is OPT-IN: add a
`<!-- shareable -->` line under its `### ` heading, then run `sync-lessons.sh`.
Untagged lessons never leave the machine.

Report what was added/updated and where.
