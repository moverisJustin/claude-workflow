---
description: Generate a cognitive briefing for seamless session handoff. Captures mental model, failed approaches, active hypotheses, and a resume prompt — not just file lists.
---

# Cognitive Handoff

## Current State
!`git branch --show-current 2>/dev/null`
!`git status --short 2>/dev/null`
!`git log --oneline -5 2>/dev/null`

---

## Cognitive Briefing Protocol

Generate a structured cognitive briefing that captures not just WHAT happened, but HOW you were THINKING. This is the difference between handing someone a changelog and handing them your brain.

### 1. Resume Prompt

Write a single paragraph (3-5 sentences) that a fresh Claude session could read to instantly reconstruct the full mental model. This is the most important part. It should answer:
- What are we building and why?
- Where exactly are we in the process?
- What's the current approach and why was it chosen?
- What's the immediate next step?

Format:
```markdown
## Resume Prompt
[Your paragraph here. Be specific. Include file names, function names, the exact problem being solved.]
```

### 2. Mental Model

Document your current understanding of the system — not the docs, but YOUR model of how things actually work based on what you've observed:

```markdown
## Mental Model
- [How component X actually works (vs how docs say it works)]
- [The real relationship between A and B]
- [The non-obvious constraint that drives the architecture]
- [What the user actually cares about vs what they said]
```

### 3. Failed Approaches (Critical)

This prevents the next session from wasting time retrying things that already didn't work:

```markdown
## Failed Approaches — Do NOT Retry
| Approach | Why it Failed | Date |
|----------|--------------|------|
| [What was tried] | [Specific reason it didn't work] | [When] |
| [Another attempt] | [Why it failed — be precise] | [When] |
```

Include error messages, wrong assumptions, API quirks discovered.

### 4. Active Hypotheses

What theories are currently being explored or tested:

```markdown
## Active Hypotheses
1. **[Hypothesis]**: [What you think might be true and why]
   - Evidence for: [what supports this]
   - Evidence against: [what contradicts this]
   - Next test: [how to validate/invalidate]
```

### 5. Decision Rationale

Not just WHAT was decided, but WHY, and what alternatives were rejected:

```markdown
## Key Decisions
| Decision | Why | Alternatives Rejected |
|----------|-----|----------------------|
| [Chose X] | [Because of Y] | [Z was considered but rejected because...] |
```

### 6. Current State Snapshot

```markdown
## State Snapshot
**Branch**: [name]
**Hot files** (most recently/frequently edited):
- `path/file.ext` — [what's happening in this file]
- `path/other.ext` — [current state]

**Tests**: [passing/failing — which ones and why]
**Build**: [clean/broken — what's wrong if broken]
**Blockers**: [anything blocking progress]
```

### 7. Priority Queue

What should happen next, in order:

```markdown
## Next Steps (Priority Order)
1. [Most important — do this first]
2. [Then this]
3. [Then this]
```

---

## Where to Save

Save the cognitive briefing to the appropriate location(s):

**If on a feature branch with task-context.md:**
- Update the Notes section of `.claude/task-context.md` with the full briefing
- The briefing travels with the branch via git

**Always update:**
- `.claude/memory/activeContext.md` — replace with the cognitive briefing
- This is the primary handoff document for `/session-start`

**Commit the updates:**
```bash
git add .claude/task-context.md .claude/memory/activeContext.md 2>/dev/null
git commit -m "chore: cognitive handoff briefing" 2>/dev/null || true
```

---

## Report

```
Cognitive Handoff Complete

Resume prompt saved to activeContext.md
[Task context updated on branch: branch-name | N/A — on main]

The next session can reconstruct full context by reading:
1. .claude/memory/activeContext.md (resume prompt + briefing)
2. .claude/task-context.md (if on a feature branch)

Key items preserved:
- Mental model ([X] items)
- Failed approaches ([X] — won't be retried)
- Active hypotheses ([X])
- Priority queue ([X] next steps)
```

---

## When to Use

- **Manually**: Run `/handoff` when you're done for the day or switching tasks
- **Auto-triggered**: The context guardian in CLAUDE.md will suggest this at 60% context usage and auto-run at 75%
- **Before `/session-end`**: `/handoff` focuses on cognitive state; `/session-end` handles the mechanical saves. Use both for maximum preservation.
- **Emergency**: If context is running critically low, run `/handoff` immediately — it's more valuable than finishing the current subtask
