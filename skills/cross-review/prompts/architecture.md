# Dimension: architecture

Review the changed code in the pack for structural defects that single-file
review misses — problems that only show up when you hold several files in
view at once.

Hunt specifically for:

- **cross-file invariants broken**: two sites that must agree (a writer and
  its readers, a schema and its consumers, a config and the code that loads
  it, duplicated constants/thresholds) where the diff changed one side only
- **coupling**: the diff reaching across a module boundary it shouldn't —
  importing internals, sharing mutable state, or duplicating logic that
  already has one canonical home
- **layering violations**: lower layers importing upward, UI logic in data
  layers, side effects in code the codebase treats as pure, bypassed
  abstractions the rest of the codebase goes through
- **lifecycle/ownership confusion**: unclear owner for init/cleanup/writes to
  a shared resource introduced or moved by the diff
- **pattern divergence**: the diff solving a problem differently from the
  established pattern the pack's memory/conventions document for this codebase

Rules:

- Judge against the codebase's OWN architecture as evidenced in the pack, not
  an ideal one; do not propose rewrites the charter doesn't ask for.
- Use category `correctness` when the structural break has a concrete failure,
  otherwise `design` for pure structure; name both files involved (`file` =
  the changed one, the counterpart in `evidence`).
- Every finding still needs a `failure_scenario`: the sequence of edits or
  events under which the structure breaks something observable.
- If you find nothing, return an empty `findings` array. Never pad.
