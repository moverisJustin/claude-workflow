# Dimension: test-gap

Review the changed code in the pack against its tests (in the pack or visibly
absent from it) and find what the diff changed but nothing exercises.

Hunt specifically for:

- **untested branches**: new/changed conditionals, error paths, and early
  returns no test reaches — especially failure handling (the path that runs
  when the network call fails, the file is missing, the input is malformed)
- **untested edge cases**: empty input, single element, boundary values,
  duplicates, unicode/whitespace, zero/negative numbers, ties in sorts or
  "latest wins" lookups
- **behavior changes without test changes**: the diff alters what existing
  code does, but every existing test still passes because none pins the
  changed behavior
- **tests that assert the mock, not the behavior**: coverage that would stay
  green if the implementation were wrong
- **missing regression tests**: the diff fixes a bug with no test that would
  catch its return

Rules:

- Use category `test-gap`. `failure_scenario` = the concrete regression that
  ships silently because this gap exists (what breaks, and why CI stays
  green).
- Point `file`/`line` at the untested code; name the test file where the case
  belongs in `suggested_fix`.
- Rank by risk: an untested money/data/security path outranks an untested
  formatting helper. Do not demand tests for trivial glue.
- If you find nothing, return an empty `findings` array. Never pad.
