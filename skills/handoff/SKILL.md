---
name: handoff
description: Generate a cognitive briefing for seamless session handoff. Captures mental model, failed approaches, active hypotheses, and a resume prompt — not just file lists.
---

# Cognitive Handoff

## Current State

Gather git state by running these commands (skip any that fail — the working directory may not be a git repo):

1. `git branch --show-current` — current branch
2. `git status --short` — uncommitted changes
3. `git log --oneline -5` — recent commits

---

## Cognitive Briefing Protocol

Generate a structured cognitive briefing that captures not just WHAT happened, but HOW you were THINKING. This is the difference between handing someone a changelog and handing them your brain.

### 0. Brief

A handoff is read cold by definition, so it opens with the Brief block from
`~/.claude/rules/writing.md`. The sections below are for whoever picks the work
up; this one is for whoever only wants to know where things stand.

```markdown
## Brief
**What this is.** [one sentence]
**Why.** [the problem, one or two sentences]
**What changes.** [three to six bullets — what moved this session]
**What you must decide.** [what is waiting on a human, or "Nothing."]
**Risk.** [what could go wrong if this sits]
```

If the session ended waiting on an answer, the `## Open decision` brief from
`.claude/task-context.md` goes here verbatim rather than being summarized. It
is already written to the contract, and paraphrasing it loses the options.

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

**On a feature branch (has `.claude/task-context.md`):**
- Write the full briefing into the Notes section of `.claude/task-context.md`.
  This is the cross-machine handoff — it travels with the branch via git.

```bash
git add .claude/task-context.md
git commit -m "chore: cognitive handoff briefing"
```

**On main (no task-context.md):**
- Ask Claude to remember the briefing so it lands in native auto-memory
  (inspect via `/memory`), which loads automatically next session. There is no
  activeContext.md — session state is native now.

---

## Publish to the team (optional — silent without a forge repo)

A handoff is a publish trigger: leaving mid-task is exactly when a teammate
needs to know where things stand. The next session — yours or theirs — sees it
surfaced at startup.

```bash
bash ~/.claude/scripts/forge-bridge.sh handoff "<briefing>"
```

Send the actionable core, not the whole briefing: ticket, branch, current
approach, what's working, what isn't, the exact next step, open questions, and
the resume prompt. Forge's writing standard is that a teammate's AI can act on
it without asking a clarifying question.

When the task later completes, close it out:

```bash
forge handoff-complete
```

---

## Report

```
Cognitive Handoff Complete

[Briefing saved to .claude/task-context.md on branch <name>
 | Briefing saved to native auto-memory (on main)]

Key items preserved:
- Mental model ([X] items)
- Failed approaches ([X] — won't be retried)
- Active hypotheses ([X])
- Priority queue ([X] next steps)
```

---

## When to Use

- **Manually**: Run `/handoff` when you're done for the day or switching tasks
- **Compaction**: covered mechanically by hooks — PreCompact writes a git-state snapshot to `.claude/memory/compaction-snapshot.md`, and the post-compaction hook directs a task-context.md handoff update (the old 60%/75% guardian percentages could never fire and are retired)
- **Before `/session-end`**: `/handoff` focuses on cognitive state; `/session-end` handles the mechanical saves. Use both for maximum preservation.
- **Emergency**: If context is running critically low, run `/handoff` immediately — it's more valuable than finishing the current subtask
