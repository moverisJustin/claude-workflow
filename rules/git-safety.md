# Git Safety

- ALL work happens on feature branches (`feature/`, `fix/`, `task/`), never on main. Exception: a brand-new project's initial build (< 5 commits).
- Every feature branch gets `.claude/task-context.md` (committed — it is the cross-machine handoff); removed when the branch merges. `/task-branch` creates it, `/task-done` finishes it.
- Verify the push target with `git remote -v` before ANY push. Never push to a production repo without explicit confirmation.
- Never force-push to main/master. Prefer `--force-with-lease` when a force is genuinely required on a feature branch.
- Verify staging before every commit: `git status --porcelain` (every intended file: non-space FIRST column), then `git diff --cached --stat`. One bad pathspec silently aborts an entire `git add`.
- **Signed commits required**: SSH signing is on by default (`commit.gpgsign true`, `gpg.format ssh`; `install.sh` configures it). Never bypass with `--no-gpg-sign` — if signing fails, fix the key/agent.
- **PR-based external review**: every change ships through a PR. Claude may merge after an external reviewer approves, but must NEVER approve its own PR.
- Recovery routing: `/rewind` (Esc-Esc) for Claude's edits; `git reset --soft HEAD^` for a bad commit; `git tag -l 'auto-checkpoint/*'` for files destroyed by bash commands (the destructive-guard hook snapshots before them).
