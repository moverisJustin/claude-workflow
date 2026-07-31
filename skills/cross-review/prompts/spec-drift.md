# Dimension: spec-drift

Compare the implementation in the pack against the pack's `## Spec under
review` section (the resolved spec: an explicit spec file, the ledger's BSpec
doc, or the task-context plan) and against the Task Charter at the top of the
pack (`## Objective` / `## Non-goals` / `## Acceptance` / `## Assumptions`).

Flag ALL THREE directions of drift:

- **Drift**: behavior the spec or charter requires that the changed code does
  not deliver, delivers differently (formats, units, defaults, error
  behavior), or delivers only partially — including Acceptance items the diff
  claims to satisfy but doesn't.
- **Scope creep**: changed code implementing things the charter's
  `## Non-goals` explicitly fence out, or that nothing in the spec asks for.
  Unrequested features are findings, not bonuses.
- **False assumption**: an entry in the charter's `## Assumptions` that the
  changed code contradicts, or that the codebase proves wrong. Those entries
  are what the author took as true **without asking** — treat every one as an
  unverified claim to attack, never as an established fact. Check each against
  the actual code. A false assumption is a finding even when the code is
  internally consistent, because the work rests on it.

Rules:

- The spec and charter are the evaluation frame; the code is the thing under
  judgment. Quote the specific spec/charter language in `evidence`.
- If the pack carries a `SPEC: none found` marker, say so in `coverage_notes`,
  limit yourself to charter-vs-code drift, and do NOT invent a spec.
- Use category `spec-drift`. `failure_scenario` = what the user/spec-holder
  expects vs what the code actually does.
- If you find nothing, return an empty `findings` array. Never pad.
