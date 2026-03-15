---
name: boris-workflow
description: The complete Boris Cherny workflow methodology for Claude Code. Covers planning, delegation, verification loops, and continuous learning. Reference this skill when orchestrating complex development tasks.
---

# Boris Workflow Methodology

This skill documents the workflow used by Boris Cherny, creator of Claude Code. Use these principles when orchestrating development tasks.

## Core Principles

### 1. Plan First, Execute Second
> "Most sessions start in Plan mode. Go back and forth until I like the plan. From there, auto-accept and Claude can usually 1-shot it."

**Implementation:**
- Always create a written plan before coding
- Get explicit approval before proceeding
- Plans should include: goal, steps, verification strategy
- A good plan enables 1-shot execution

### 2. Verification is Everything
> "Give Claude a way to verify its work. If Claude has that feedback loop, it will 2-3x the quality."

**Implementation:**
- Every change must pass automated checks
- Tests, types, lint, build - all must pass
- Manual verification for UI changes
- Never skip verification to save time

### 3. Living Documentation
> "Anytime we see Claude do something incorrectly we add it to CLAUDE.md, so Claude knows not to do it next time."

**Implementation:**
- Update CLAUDE.md after every mistake
- Document patterns that work well
- Keep commands and processes current
- This compounds over time

### 4. Delegate to Specialists
> "I use subagents regularly: code-simplifier, verify-app, and so on."

**Implementation:**
- Use Task tool to invoke specialist agents
- Match agent to task type
- Don't do everything yourself
- Specialists have focused expertise

### 5. Automate the Inner Loop
> "I use slash commands for every workflow I do many times a day."

**Implementation:**
- Create commands for repeated workflows
- Commands should be self-contained
- Pre-compute context with inline bash
- Check commands into git for team sharing

## The Boris Orchestration Pattern

When handling a task as the Boris orchestrator:

```
1. UNDERSTAND
   - Parse the user's request
   - Identify implicit requirements
   - Assess scope and complexity

2. PLAN
   - Create detailed execution plan
   - Identify which agents to use
   - Define verification criteria
   - Present plan for approval

3. EXECUTE
   - Delegate to appropriate agents
   - Maintain coordination
   - Handle failures gracefully
   - Track progress

4. VERIFY
   - Run all automated checks
   - Invoke verify-app agent
   - Use code-simplifier to clean up
   - Iterate until all checks pass

5. SHIP
   - Commit with good message
   - Create PR with context
   - Update CLAUDE.md if learned something
   - Report completion
```

## Agent Selection Guide

| Task Type | Agent | When to Use |
|-----------|-------|-------------|
| Design decisions | code-architect | Before major implementations |
| Writing tests | test-writer | New features need tests |
| Code review | pr-reviewer | Before merging any PR |
| Cleanup | code-simplifier | After implementation complete |
| Verification | verify-app | Before shipping anything |
| Documentation | doc-generator | After significant changes |
| Incidents | oncall-guide | Production issues |

## Verification Checklist

Before considering any task complete:

- [ ] All tests pass
- [ ] TypeScript compiles without errors
- [ ] Linting passes
- [ ] Build succeeds
- [ ] Code has been simplified/cleaned
- [ ] Documentation updated if needed
- [ ] CLAUDE.md updated if learned something

## Quality Standards

**Code Quality:**
- Functions under 20 lines
- Clear naming
- Appropriate error handling
- No code duplication

**Test Quality:**
- Tests cover happy path
- Tests cover edge cases
- Tests cover error handling
- Mocks are appropriate

**Documentation Quality:**
- Examples are copy-paste ready
- All public APIs documented
- CLAUDE.md is current

## Anti-Patterns to Avoid

❌ Implementing without a plan
❌ Skipping verification to save time
❌ Not updating CLAUDE.md after mistakes
❌ Doing everything yourself instead of delegating
❌ Committing without passing all checks
❌ Ignoring test failures
❌ Hardcoding values
❌ Not handling errors

## Session Flow

**Starting a session:**
1. Run `/session-start` to load context
2. Review CLAUDE.md for reminders
3. Check git status for pending work

**During a session:**
1. Use `/boris` for complex tasks
2. Use specific commands for simple tasks
3. Verify frequently
4. Commit often

**Ending a session:**
1. Run `/session-end`
2. Commit or stash all work
3. Update CLAUDE.md with learnings
4. Push to remote
