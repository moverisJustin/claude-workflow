# Plan: Integrate Router & Drift Detection into Claude Workflow

## Goal
Add two MEX-inspired features to the existing Boris v2.0 workflow:
1. **Context Router** — load only task-relevant memory files instead of everything
2. **Drift Detection** — validate that Memory Bank files still match codebase reality

Both features slot into the existing system as enhancements, not replacements.

---

## Part 1: Context Router

### Problem
Currently, `/session-start` loads ALL Memory Bank files every session (~2,500+ words from CLAUDE.md alone, plus 6 memory files). As learned patterns and conventions grow, this becomes increasingly wasteful — a simple test-writing task doesn't need the full decision log or architecture context.

### Design

#### 1.1 Create `ROUTER.md` template
**File**: `context/ROUTER.md` (template shipped with claude-workflow, copied to `.claude/memory/ROUTER.md` per project by `/memory-init`)

**Structure**:
```markdown
# Context Router

## Always Load (~150 tokens)
- `.claude/memory/activeContext.md` (resume prompt, current focus)
- `.claude/task-context.md` (if on feature branch)

## Route by Task Type

| Task Signal | Load These Files |
|-------------|-----------------|
| new feature, implement, build, add | conventions.md, projectContext.md, patterns/INDEX.md |
| bug fix, debug, investigate, error | conventions.md, activeContext.md (full), decisionLog.md |
| test, spec, coverage | conventions.md, patterns/testing.md |
| refactor, simplify, clean up | conventions.md, projectContext.md, decisionLog.md |
| architecture, design, plan | projectContext.md, decisionLog.md, conventions.md |
| deploy, CI, release | conventions.md, setup.md |
| review, audit | conventions.md, decisionLog.md, projectContext.md |
| docs, README | projectContext.md, progress.md |

## Fallback
If task doesn't match any signal above, load: activeContext.md, conventions.md, projectContext.md
```

**Key design decisions**:
- `activeContext.md` (resume prompt section only, ~100 tokens) and `task-context.md` ALWAYS load — they're the "where was I?" anchor
- Route matching is keyword-based from the user's first message or task description
- `conventions.md` loads for almost everything (it's the "don't repeat mistakes" file)
- Full `sessionHistory.md` and `progress.md` are rarely needed at session start — load on demand

#### 1.2 Create `patterns/` directory support
**File**: `context/patterns/INDEX.md` (template)

An indexed registry of task-specific guides that grows from real work:
```markdown
# Pattern Index

| Pattern | File | Last Updated |
|---------|------|-------------|
| Add API endpoint | patterns/add-api-endpoint.md | 2026-03-28 |
| Debug pipeline | patterns/debug-pipeline.md | 2026-03-25 |
```

Patterns are optional and project-specific. `/memory-init` creates the empty directory + INDEX.md. The `/session-end` command gets a "GROW" step that prompts: "Did this task reveal a reusable pattern? If yes, create/update a pattern file and INDEX.md."

#### 1.3 Modify `/session-start` command
Update `commands/session-start.md` to:

1. Read ROUTER.md first (small file, always loaded)
2. Classify the user's task/message against the routing table
3. Load only the matched files (instead of all 6)
4. If no task provided yet (just a greeting), load the "Fallback" set
5. Preserve the existing state summary output format

**Before** (current):
```
Read ALL: projectContext.md, activeContext.md, progress.md,
conventions.md, sessionHistory.md, decisionLog.md
```

**After** (routed):
```
Read: ROUTER.md → classify task → load 2-3 relevant files
```

#### 1.4 Add `/load-context` command
**New file**: `commands/load-context.md`

For mid-session context loading when the task changes:
```
/load-context architecture   → loads projectContext.md + decisionLog.md
/load-context debug          → loads conventions.md + decisionLog.md
```

This replaces manually reading files when switching task types within a session.

#### 1.5 Modify `/memory-init` command
Update `commands/memory-init.md` to also:
- Create `.claude/memory/ROUTER.md` (from template, customized for the project)
- Create `.claude/memory/patterns/` directory
- Create `.claude/memory/patterns/INDEX.md` (empty registry)

#### 1.6 Modify `/session-end` command
Update `commands/session-end.md` to add a "GROW" step:
- After generating the session summary, ask: "Should a reusable pattern be created from this task?"
- If yes, create `patterns/<name>.md` and update `patterns/INDEX.md`
- Update ROUTER.md's "Current Project State" section (if we add one, similar to MEX)

---

## Part 2: Drift Detection

### Problem
Memory Bank files can silently go stale — referencing deleted files, outdated dependencies, removed branches, or conventions for tools no longer in use. There's no automated way to detect this.

### Design

#### 2.1 Create `mex-check` script
**File**: `scripts/drift-check.sh`

A bash script (zero AI tokens, pure static analysis) that runs 5 checkers:

| Checker | What It Detects | Severity |
|---------|----------------|----------|
| **path** | File paths in Memory Bank `.md` files that don't exist on disk | Error (-10) |
| **branch** | Branch names in progress.md / task-context.md that no longer exist | Warning (-3) |
| **dependency** | Package names in conventions.md / stack.md not in package.json (or requirements.txt, Cargo.toml, etc.) | Warning (-3) |
| **staleness** | Memory Bank files not updated in 30+ days or 50+ commits | Info (-1) |
| **command** | CLI commands referenced in Memory Bank that don't resolve (npm scripts, make targets) | Warning (-3) |

**Output**: Drift score (starts at 100, deducts per finding) + actionable list.

```
$ bash .claude/scripts/drift-check.sh
[DRIFT CHECK] Score: 87/100
  ERROR: conventions.md:23 references src/utils/auth.ts (file not found)
  WARN:  progress.md:8 references branch feature/payments (branch deleted)
  WARN:  conventions.md:45 references package 'lodash' (not in package.json)
  INFO:  decisionLog.md last updated 42 days ago
```

**Why bash, not Node/TypeScript**:
- Zero dependencies — works in any project regardless of stack
- Runs instantly with no build step
- Can be called from hooks, CI, or manually

#### 2.2 Create `/drift-check` command
**New file**: `commands/drift-check.md`

A slash command that:
1. Runs `drift-check.sh`
2. Presents findings with suggested fixes
3. Optionally auto-fixes simple issues (remove dead path references, update stale timestamps)

Can also be invoked as part of `/session-start` (if score < threshold, warn the user).

#### 2.3 Integrate into `/session-start`
Add a lightweight drift check to the session start flow:
- Run `drift-check.sh --quiet` (one-line score output)
- If score < 80: warn the user and suggest `/drift-check` for details
- If score >= 80: proceed silently (don't waste tokens on "all good")

#### 2.4 Add post-commit hook option
**File**: `scripts/hook-drift-watch.sh`

Optional post-commit hook (installed via settings.base.json):
- Runs `drift-check.sh --quiet` after each commit
- Only outputs if score drops below 80 (silent otherwise)
- Keeps scaffold honest as code evolves

#### 2.5 Integrate into `/session-end`
Add to the session-end flow:
- After updating Memory Bank files, run drift check
- If new drift introduced by the session's own updates, fix before saving

---

## Part 3: Integration & Installation

#### 3.1 New files to create
```
commands/drift-check.md          # Slash command for drift detection
commands/load-context.md         # Mid-session context routing
context/ROUTER.md                # Router template
context/patterns/INDEX.md        # Pattern registry template
scripts/drift-check.sh           # Drift detection bash script
```

#### 3.2 Files to modify
```
commands/session-start.md        # Add routing + drift check
commands/session-end.md          # Add GROW step + drift check
commands/memory-init.md          # Create ROUTER.md + patterns/
agents/memory-bank.md            # Document router & drift in agent spec
settings.base.json               # Add drift-watch hook (optional)
CLAUDE.md                        # Document new commands in quick reference
CHEATSHEET.md                    # Add to cheatsheet
install.sh                       # Copy new files during install
```

#### 3.3 Backward compatibility
- Projects without ROUTER.md fall back to current behavior (load everything)
- `/session-start` checks for ROUTER.md existence before routing
- Drift check is advisory, never blocking
- Pattern directory is optional — INDEX.md can be empty

---

## Implementation Order

1. **Phase 1 — Router template + `/load-context`** (new files, no existing changes)
   - Create `context/ROUTER.md`
   - Create `context/patterns/INDEX.md`
   - Create `commands/load-context.md`

2. **Phase 2 — Drift detection script + command** (new files, no existing changes)
   - Create `scripts/drift-check.sh`
   - Create `commands/drift-check.md`

3. **Phase 3 — Integrate into existing commands** (modify existing files)
   - Update `commands/session-start.md` (routing + drift warning)
   - Update `commands/session-end.md` (GROW step + drift check)
   - Update `commands/memory-init.md` (create router + patterns dir)

4. **Phase 4 — Documentation & install** (modify existing files)
   - Update `agents/memory-bank.md`
   - Update `settings.base.json` (optional drift hook)
   - Update `CLAUDE.md` quick reference
   - Update `install.sh`

5. **Phase 5 — Commit & push**
   - Commit all changes to `claude/compare-mex-workflow-O3aJU`
   - Push to remote

---

## What This Does NOT Do
- Does NOT replace the Memory Bank — enhances it
- Does NOT require MEX as a dependency — standalone implementation
- Does NOT break existing projects — fully backward compatible
- Does NOT add Node.js/TypeScript dependencies — bash only for scripts
- Does NOT change the CLAUDE.md loading behavior — CLAUDE.md is still always loaded by Claude Code itself; routing applies to Memory Bank files only
