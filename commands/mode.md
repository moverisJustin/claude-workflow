---
description: Switch between operational modes (architect, code, debug, review, audit). Each mode has different tool access and behavioral constraints.
---

# Mode Control

## Current Mode
!`cat .claude/current-mode 2>/dev/null`

---

## Mode Switch

Target Mode: $ARGUMENTS

---

## Available Modes

### 🏗️ Architect Mode
**Purpose**: Design and planning only
**Access**: Read-only, no file modifications
**Use for**: System design, architecture review, planning

### 💻 Code Mode (Default)
**Purpose**: Active development
**Access**: Full tool access
**Use for**: Implementation, bug fixes, features

### 🔍 Debug Mode
**Purpose**: Investigation and diagnosis
**Access**: Read-heavy, limited writes
**Use for**: Troubleshooting, root cause analysis

### 👀 Review Mode
**Purpose**: Code review only
**Access**: Strictly read-only
**Use for**: PR review, code audit

### 🔒 Audit Mode
**Purpose**: Security and compliance
**Access**: Read-only with full logging
**Use for**: Security scans, compliance checks

---

## Mode Switching Protocol

### 1. Validate Target Mode

Valid modes: `architect`, `code`, `debug`, `review`, `audit`

### 2. Save Current Context

Before switching:
- Note current work state
- Save any pending changes
- Update Memory Bank

### 3. Apply Mode

```bash
echo "$TARGET_MODE" > .claude/current-mode
echo "$(date +%Y-%m-%d_%H:%M:%S) MODE_SWITCH to $TARGET_MODE" >> .claude/audit/mode.log
```

### 4. Announce Mode Change

```
🎛️ Mode Changed

From: [previous mode]
To: [new mode]

Capabilities:
✅ [What you CAN do]
❌ [What you CANNOT do]

To change: /mode [mode-name]
```

### 5. Mode-Specific Behaviors

**Architect Mode:**
```
I am now in Architect mode.

I WILL:
- Read and analyze code
- Create design documents
- Suggest architectural improvements
- Delegate to other agents

I WILL NOT:
- Edit source files
- Make commits
- Run modifying commands
```

**Code Mode:**
```
I am now in Code mode.

Full development capabilities enabled.
All tools available.
```

**Debug Mode:**
```
I am now in Debug mode.

I WILL:
- Investigate issues systematically
- Read logs and error messages
- Add diagnostic output (with confirmation)

I WILL LIMIT:
- Direct code changes
- Refactoring
- Feature additions
```

**Review Mode:**
```
I am now in Review mode.

I WILL:
- Read and analyze code
- Generate review feedback
- Identify issues and suggestions

I WILL NOT:
- Modify any files
- Make commits
- Apply fixes directly
```

**Audit Mode:**
```
I am now in Audit mode.

I WILL:
- Scan for security issues
- Check for compliance
- Generate audit reports
- Log all file access

I WILL NOT:
- Modify any files
- Make any changes
```

---

## Mode Permission Matrix

| Action | Architect | Code | Debug | Review | Audit |
|--------|-----------|------|-------|--------|-------|
| Read files | ✅ | ✅ | ✅ | ✅ | ✅ |
| Search code | ✅ | ✅ | ✅ | ✅ | ✅ |
| Edit files | ❌ | ✅ | ⚠️ | ❌ | ❌ |
| Write files | ⚠️ | ✅ | ⚠️ | ❌ | ❌ |
| Git commit | ❌ | ✅ | ❌ | ❌ | ❌ |
| Run tests | ✅ | ✅ | ✅ | ✅ | ✅ |
| Run builds | ✅ | ✅ | ✅ | ✅ | ❌ |

Legend: ✅ Allowed | ❌ Blocked | ⚠️ Requires confirmation

---

## Quick Mode Commands

```
/mode architect  # Design mode
/mode code       # Development mode (default)
/mode debug      # Investigation mode
/mode review     # Review mode
/mode audit      # Security audit mode
/mode            # Show current mode
```
