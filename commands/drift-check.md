---
description: Run drift detection on Memory Bank files. Validates that documentation matches codebase reality and suggests fixes.
---

# Drift Check

## Step 1: Run Static Analysis

Run the drift detection script:

```bash
bash .claude/scripts/drift-check.sh
```

If the script doesn't exist at `.claude/scripts/drift-check.sh`, check `~/.claude/scripts/drift-check.sh` as a fallback (installed globally by claude-workflow).

## Step 2: Present Findings

Parse the output and present findings grouped by severity:

```
Drift Report — Score: [X]/100

ERRORS (documentation references things that don't exist):
- [file:line] [description]

WARNINGS (documentation may be out of date):
- [file:line] [description]

INFO (documentation may need refresh):
- [file:line] [description]
```

If score is 100: "Memory Bank is fully in sync with the codebase."

## Step 3: Suggest Fixes

For each finding, suggest a specific fix:

| Finding Type | Suggested Fix |
|-------------|---------------|
| Dead file path | Remove the reference, or update to the correct path if the file was moved |
| Dead branch | Remove from progress.md / activeContext.md |
| Missing dependency | Remove from conventions/projectContext, or add the package back |
| Stale file | Re-read the relevant part of the codebase and update the memory file |
| Dead command | Remove the command reference, or add the script to package.json |

## Step 4: Auto-Fix (if user approves)

Ask: "Would you like me to auto-fix these findings?"

If yes, apply fixes in order:
1. **Dead paths**: Remove lines referencing non-existent files (or update if the file was clearly moved)
2. **Dead branches**: Remove stale branch references from progress tracking
3. **Missing deps**: Remove stale package references from conventions
4. **Stale files**: Read current codebase state and refresh the stale memory file
5. **Dead commands**: Remove or update command references

After auto-fix, re-run the drift check to verify the score improved.

## Step 5: Report

```
Drift Check Complete

Before: [X]/100
After:  [Y]/100 (if auto-fix was applied)
Fixed:  [N] findings
Remaining: [M] findings (manual review needed)
```

## Notes
- Drift check is **advisory, never blocking** — it doesn't prevent work
- The script uses zero AI tokens — it's pure bash static analysis
- For continuous monitoring, the post-commit hook (`hook-drift-watch.sh`) runs this automatically
- Score thresholds: 90+ is healthy, 70-89 needs attention, <70 needs immediate cleanup
