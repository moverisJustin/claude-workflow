# Git Safety

- **Never assume the base branch is `main`.** Resolve it per repo:
  ```bash
  bash ~/.claude/scripts/resolve-base-branch.sh --base
  ```
  Repos differ more than you'd expect — a survey of one org's 55 active repos found `main` (43), `master` (6), and `develop`+`main` gitflow (6). Hardcoding `main` silently branches off the wrong base, or fails outright where the branch is `master`. The resolver reads what merged PRs actually target, then caches the answer in `.claude/project-config.json`; `--explain` shows the evidence, and an explicit `base_branch` in that file always wins.
- ALL work happens on feature branches (`feature/`, `fix/`, `task/`), never on a **protected** branch. Protected means *every* branch that receives PRs — in gitflow that is both `develop` and `main`, so "not on main" is not enough:
  ```bash
  bash ~/.claude/scripts/resolve-base-branch.sh --protected
  ```
  Exception: a brand-new project's initial build (< 5 commits).
- Every feature branch gets `.claude/task-context.md` (committed — it is the cross-machine handoff); removed when the branch merges. `/task-branch` creates it, `/task-done` finishes it.
- Verify the push target with `git remote -v` before ANY push. Never push to a production repo without explicit confirmation.
- Never force-push to ANY protected branch (see above — not just `main`/`master`). Prefer `--force-with-lease` when a force is genuinely required on a feature branch.
- Verify staging before every commit: `git status --porcelain` (every intended file: non-space FIRST column), then `git diff --cached --stat`. One bad pathspec silently aborts an entire `git add`.
- **Signed commits required**: SSH signing is on by default (`commit.gpgsign true`, `gpg.format ssh`; `install.sh` configures it). Never bypass with `--no-gpg-sign` — if signing fails, fix the key/agent.
- **PR-based external review**: every change ships through a PR. Claude may merge after an external reviewer approves, but must NEVER approve its own PR.
- Recovery routing: `/rewind` (Esc-Esc) for Claude's edits; `git reset --soft HEAD^` for a bad commit; `git tag -l 'auto-checkpoint/*'` for files destroyed by bash commands (the destructive-guard hook snapshots before them).
