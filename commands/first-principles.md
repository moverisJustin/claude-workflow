---
description: Apply first principles thinking to break down complex problems and find optimal solutions
---

# First Principles Analysis

**Problem**: $ARGUMENTS

---

## Framework

### Step 1: What are we actually trying to achieve?
Strip away assumptions. What is the fundamental goal?

### Step 2: What are the absolute constraints?
Not "how it's usually done" but physical/logical limits:
- Technical constraints (what's actually impossible)
- Business constraints (actual requirements)
- Time/resource constraints (real limits)

### Step 3: What assumptions are we making?
List every assumption, then challenge each:
- Is this actually true?
- Is this how it HAS to be, or how it's usually done?
- What if this assumption were wrong?

### Step 4: What are the fundamental building blocks?
Break down to atomic components:
- What are the inputs?
- What are the outputs?
- What transformations are needed?

### Step 5: Rebuild from fundamentals
Now construct the solution from first principles:
- What's the simplest path from inputs to outputs?
- What's actually necessary vs nice-to-have?
- What would we build if starting from scratch?

---

## Output Format

```markdown
## First Principles Analysis: [Problem]

### Fundamental Goal
[What we actually need to achieve]

### Real Constraints
1. [Constraint that can't be changed]
2. [Another real limit]

### Challenged Assumptions
| Assumption | Status | Reasoning |
|------------|--------|-----------|
| "We need X" | ❌ False | Actually we need Y |
| "Must use Z" | ✅ True | Required for [reason] |

### Building Blocks
- Input: [What we start with]
- Output: [What we need]
- Core operation: [Fundamental transformation]

### First Principles Solution
[The approach derived from fundamentals]

### Comparison
| Aspect | Conventional | First Principles |
|--------|--------------|------------------|
| Complexity | High | Lower |
| Time | X days | Y days |
| Maintenance | Hard | Easier |

### Recommendation
[Which approach and why]
```
