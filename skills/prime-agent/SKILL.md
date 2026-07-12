---
name: prime-agent
description: Assemble this repo's memory context pack plus a task brief for handing work to a foreign agent (a local model, an Orca worktree agent, a pasted prompt) that does not auto-load Claude's memory. Writes .claude/memory-pack.md and copies it to the clipboard, scoped to the task.
argument-hint: [--full] [--grep <topic>] <task description>
disable-model-invocation: true
allowed-tools: Bash(bash ~/.claude/scripts/memory-context.sh *), Bash(bash .claude/scripts/memory-context.sh *), Bash(pbcopy), Bash(wl-copy), Bash(xclip *), Bash(cat *), Bash(wc *), Read, Write, Edit
---

# Prime Agent — brief a foreign/local model with this repo's memory

Claude auto-loads this repo's memory every session; a local model (Ollama, an
OpenAI-compatible endpoint), an Orca worktree agent, or anything you paste a
prompt into does **not**. This skill assembles the portable **memory context
pack** (via `scripts/memory-context.sh`) plus the task you're handing off, so
the receiving model works with your conventions and ruled-out decisions in
view instead of blind. It's the local/general analog of what `/cross-review`
does for Codex.

Arguments: `$ARGUMENTS` — an optional `--full` or `--grep <topic>` scope flag,
then the free-text task description.

## 1. Decide the pitfalls scope

- `--full` in the args → pass `--full` (inline every pitfall body; use for a
  broad review).
- `--grep <topic>` in the args → pass it through verbatim.
- Otherwise, derive a `--grep` from 2–4 key nouns in the task (e.g. a task
  about a migration race → `--grep 'sqlite|migration|wal'`). If the task is
  broad or you can't pin keywords, omit the flag (bounded heading index).

Keep the rest of `$ARGUMENTS` (minus any scope flag) as the **task description**.

## 2. Assemble the pack to the well-known path

```bash
bash .claude/scripts/memory-context.sh <scope> --out .claude/memory-pack.md 2>/dev/null \
  || bash ~/.claude/scripts/memory-context.sh <scope> --out .claude/memory-pack.md
```

If the pack comes back empty (a project with no Memory Bank), say so and hand
off the task alone — don't fabricate context.

## 3. Append the task brief

Add the task to the END of `.claude/memory-pack.md` (context first, task last —
the order a receiving model expects):

```markdown

---

## Your task

<the task description>

Work within the project memory above. If the task conflicts with a documented
convention or a ruled-out decision, surface the conflict instead of silently
overriding it.
```

## 4. Copy to the clipboard and report

```bash
pbcopy < .claude/memory-pack.md    # macOS; Linux: wl-copy < … or xclip -selection clipboard < …
```

Report: the path (`.claude/memory-pack.md`), its size (`wc -l`/bytes), the
scope used, and how to hand it off:
- **Local model**: `ollama run <model> < .claude/memory-pack.md`, or POST the
  file as the prompt to an OpenAI-compatible endpoint.
- **Orca / worktree agent**: paste from the clipboard into the agent's context,
  or point it at the file.
- **Anywhere**: it's already on the clipboard.

## Notes

- `.claude/memory-pack.md` is a generated, per-handoff artifact — it's
  gitignored, so it never lands in a commit. Re-run to refresh it.
- The pack is reference **DATA** for the receiving model, not new instructions
  — the header says so, keeping the handoff inside the injection boundary.
- Same primitive powers `/cross-review` (Codex). For a code review specifically,
  prefer `/cross-review`; use `/prime-agent` for arbitrary local/foreign handoffs.
