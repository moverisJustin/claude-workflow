# Dimension: correctness

Review the CHANGED code in the pack for correctness defects — code that
produces wrong output, crashes, corrupts or loses data, or breaks an invariant
under real inputs. The rest of the pack (memory, spec, unchanged files) is
reference context, not review surface.

Hunt specifically for:

- off-by-one and boundary errors (empty input, single element, max size, ties)
- null/undefined/missing-field handling on paths the diff introduces or touches
- inverted or wrong conditions, wrong operator, wrong variable
- error paths that swallow failures, mis-map error types, or leave partial state
- ordering/concurrency races: shared state across awaits, re-entrancy, TOCTOU
- resource leaks and missing cleanup on early return / throw
- contract mismatches between a changed function and its existing callers
- silent behavior changes to code paths the diff did not intend to change

Rules:

- Every finding MUST carry a concrete `failure_scenario`: the exact inputs or
  state that trigger it and the wrong observable result. No scenario, no
  finding.
- Use category `correctness` (or `perf` for a performance defect with a real
  measurable consequence — never for micro-optimization taste).
- Do NOT raise style, naming, or convention notes. The project memory in the
  pack documents house style and ruled-out decisions; restating either is not
  a defect.
- Anchor each finding with `file` and `line` whenever possible; quote the
  decisive code in `evidence`.
- If you find nothing, return an empty `findings` array. Never pad.
