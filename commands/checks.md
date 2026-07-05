---
description: Run the project's own quality gates (tests, types, lint, format, build) - stack-detected, no blind polyglot volleys. Sets a verify gate the Stop hook enforces until green.
---

# Checks

Run only the gates this project actually has. Never fire npm and pytest
blindly at the same repo — detect the stack first, then run that stack's
gates. Use native `/verify` when behavioral verification (run the app,
observe it) is needed on top of these static gates.

## 1. Detect the stack

Look for (in the project root):
- `package.json` → Node stack. Read its `scripts` block; only run scripts
  that exist: `test`, `typecheck` (or `tsc --noEmit` if tsconfig.json exists
  and no script), `lint`, `build`.
- `pyproject.toml` / `setup.py` / `setup.cfg` → Python stack:
  - `pytest` if a tests/ dir or test_*.py files exist
  - `ruff check .` AND `ruff format --check .` if ruff is configured
    (BOTH — a repo can be lint-clean and still fail CI on formatting)
  - `mypy .` only if mypy is configured (pyproject section or mypy.ini)
- `Cargo.toml` → `cargo test`, `cargo clippy`, `cargo fmt --check`
- `go.mod` → `go test ./...`, `go vet ./...`
- Both Node and Python present → run both stacks (a genuine hybrid repo).
- None of the above → report "no recognized stack" and stop. Do NOT guess.

## 2. Set the verify gate

Before running gates, arm the Stop-hook gate so the session cannot be
declared done while checks fail. Always anchor to the PROJECT ROOT (the
Bash cwd may be a subdirectory) and use the self-gitignored audit dir so
an armed gate can never be committed by `git add -A`:

```bash
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
mkdir -p "$ROOT/.claude/audit"
grep -qx '*' "$ROOT/.claude/audit/.gitignore" 2>/dev/null || echo '*' > "$ROOT/.claude/audit/.gitignore"
echo "attempts=0" > "$ROOT/.claude/audit/verify-gate"
```

Known limitation: the gate is project-scoped, not session-scoped — two
concurrent Claude sessions in the same directory share it (the 3-attempt
escape hatch caps the blast radius).

## 3. Run the gates

Run each applicable gate ONE AT A TIME and capture real results. Do not
mask failures with `|| true` — a gate that fails must surface its output.

## 4. Iterate until green

- If a gate fails: fix the root cause, re-run that gate, then re-run the
  full set once more (fixes can break other gates).
- The Stop hook (`hook-stop-verify.sh`) will push back if the turn ends
  while `.claude/audit/verify-gate` is still armed — this is by design.
- If a gate CANNOT pass (pre-existing breakage unrelated to the change,
  missing credentials, flaky infra): say so explicitly with the output,
  then clear the gate — never leave it armed on a false pretext.

## 5. Clear the gate

Only when every applicable gate passes (or step 4's cannot-pass exception
is explicitly reported):

```bash
rm -f "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude/audit/verify-gate"
```

## 6. Report

```markdown
## Checks: [PASS/FAIL]

| Gate | Result |
|---|---|
| npm test | pass (42 tests) |
| tsc --noEmit | pass |
| ruff check + format --check | pass |

[If failures: what failed, root cause, what was fixed, re-run result]
Verify gate: cleared
```
