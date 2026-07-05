export const meta = {
  name: 'boris-build',
  description: 'Boris fan-out engine: partition an approved plan into disjoint work items, implement in parallel, verify until green. Never commits or pushes.',
  whenToUse: 'Launched by the /boris skill AFTER plan-mode approval, for tasks that decompose into many independent work items (multi-module features, migrations, sweeping refactors). Not for small or tightly-coupled changes.',
  phases: [
    { title: 'Partition', detail: 'split the approved plan into file-disjoint work items' },
    { title: 'Implement', detail: 'one agent per work item, tests included' },
    { title: 'Verify', detail: 'project gates + adversarial review of each item, one fix round' },
  ],
}

// args: { task: string  — the approved plan's objective, constraints, and any
//         file scope. Passed by the /boris skill. }
const TASK = (args && args.task) || ''
if (!TASK) {
  return { error: 'boris-build requires args.task (the approved plan). Launch via the /boris skill.' }
}

const PARTITION_SCHEMA = {
  type: 'object', required: ['items'],
  properties: {
    items: { type: 'array', maxItems: 24, items: {
      type: 'object', required: ['title', 'instructions', 'files'],
      properties: {
        title: { type: 'string' },
        instructions: { type: 'string', description: 'self-contained implementation brief: what to build, acceptance criteria, conventions to follow' },
        files: { type: 'array', items: { type: 'string' }, description: 'files this item owns exclusively' },
      },
    }},
    shared_context: { type: 'string', description: 'facts every implementer needs (patterns, naming, constraints)' },
  },
}
const GATE_SCHEMA = {
  type: 'object', required: ['passed', 'report'],
  properties: { passed: { type: 'boolean' }, report: { type: 'string' } },
}
const REVIEW_SCHEMA = {
  type: 'object', required: ['ok', 'issues'],
  properties: { ok: { type: 'boolean' }, issues: { type: 'array', items: { type: 'string' } } },
}

phase('Partition')
const plan = await agent(`Partition this approved implementation plan into independent work items for parallel implementation.

HARD REQUIREMENTS:
- Items must be FILE-DISJOINT — no two items may list or touch the same file (implementers run concurrently in one working tree; the workflow REJECTS overlapping partitions). A shared file every module needs to touch (barrel/index file, package.json, route registration) must belong to exactly ONE item — put the shared-file wiring for ALL modules into that one item's instructions, or explicitly note it as "left for the main conversation to wire up" in shared_context.
- Anything tightly coupled goes into ONE item. Include test files in the owning item.
- Keep it to at most ~12 items; merge related work rather than fragmenting.
- Read the codebase as needed to make instructions self-contained (each implementer starts with zero context beyond what you write).
Also produce shared_context: conventions, patterns, and constraints every implementer must follow.

APPROVED PLAN:
${TASK}`, { label: 'partition', phase: 'Partition', schema: PARTITION_SCHEMA, effort: 'high' })

if (!plan || !plan.items) {
  return { error: 'Partition stage failed (no plan produced). Nothing was implemented.' }
}
if (plan.items.length === 0) {
  return { error: 'Partition produced zero work items — the plan may be vague or already satisfied. Nothing was implemented; handle this task in the main conversation.' }
}
// Mechanically enforce the file-disjointness the whole design rests on.
{
  const owners = {}
  const collisions = []
  plan.items.forEach(item => (item.files || []).forEach(f => {
    if (owners[f]) collisions.push(`${f} (owned by "${owners[f]}" and "${item.title}")`)
    else owners[f] = item.title
  }))
  if (collisions.length) {
    return { error: `Partition violated file-disjointness — refusing to run concurrent implementers over shared files. Collisions: ${collisions.join('; ')}. Re-run with a merged partition or handle in the main conversation.` }
  }
}
log(`${plan.items.length} work items, file-disjoint verified`)

phase('Implement')
const implemented = await parallel(plan.items.map((item, i) => () =>
  agent(`Implement ONE work item of a larger approved plan. Stay strictly within your owned files — other agents own the rest concurrently. If correct implementation truly requires touching a file you do not own, DO NOT touch it: finish your owned files and state the needed external change in your report.

SHARED CONTEXT:
${plan.shared_context || '(none)'}

WORK ITEM: ${item.title}
OWNED FILES (touch ONLY these): ${item.files.join(', ')}

INSTRUCTIONS:
${item.instructions}

Follow the codebase's existing conventions (read neighboring code first). Write/update tests within your owned files. Do NOT run git commands. Return a terse report: files changed, what was done, anything the verifier should scrutinize.`,
    { label: `impl:${i}:${item.title.slice(0, 24)}`, phase: 'Implement' })
    .then(report => ({ item, report, failed: !report }))
))

const done = implemented.filter(Boolean).filter(r => !r.failed)
const failedItems = implemented.filter(Boolean).filter(r => r.failed).map(r => r.item.title)
if (failedItems.length) log(`WARNING: ${failedItems.length} implementer(s) died: ${failedItems.join(', ')} — their files may be half-written`)

phase('Verify')
// Barrier justified: gates must run over the COMBINED result of all items.
const runGates = label => agent(`Run this project's quality gates over the current working tree (detect the stack first: package.json scripts / pyproject / Cargo.toml / go.mod — run only gates that exist; include ruff format --check for Python). Do NOT run git commit/push. Report every failure with its output.`,
  { label, phase: 'Verify', schema: GATE_SCHEMA })
const gates = (await runGates('gates')) || { passed: false, report: 'gate-runner agent failed — treat as not verified' }

const reviews = await parallel(done.map(({ item, report }, i) => () =>
  agent(`Adversarially review one implemented work item. Read the actual files and try to find real defects (correctness, missed acceptance criteria, convention violations) — not style nits.

WORK ITEM: ${item.title}
OWNED FILES: ${item.files.join(', ')}
SPEC: ${item.instructions}
IMPLEMENTER REPORT: ${report}`,
    { label: `review:${i}:${item.title.slice(0, 24)}`, phase: 'Verify', schema: REVIEW_SCHEMA, effort: 'high' })
    // A dead reviewer must surface as "needs manual review", never as a pass.
    .then(r => ({ item, review: r || { ok: false, issues: ['reviewer agent failed — this item needs manual review'] } }))
))

// One fix round: per-item fixes for review findings (still file-disjoint),
// then a single gate-fixer for cross-item gate failures (may touch any file,
// so it runs strictly AFTER the parallel item fixes).
const broken = reviews.filter(Boolean).filter(r => !r.review.ok)
let fixReports = []
let finalGates = gates
if (broken.length || !gates.passed) {
  log(`fix round: ${broken.length} flagged items, gates passed=${gates.passed}`)
  if (broken.length) {
    fixReports = await parallel(broken.map(({ item, review }, i) => () =>
      agent(`Fix the confirmed issues in this work item (owned files: ${item.files.join(', ')}). Issues:\n- ${review.issues.join('\n- ')}\nSpec:\n${item.instructions}\nDo not run git commands. Report what you changed.`,
        { label: `fix:${i}:${item.title.slice(0, 24)}`, phase: 'Verify' })))
  }
  if (!gates.passed) {
    const gateFix = await agent(`The project's quality gates are failing after a multi-item implementation. Diagnose and fix the ROOT CAUSES — cross-item integration breaks are likely (missing wiring/exports/deps between independently implemented modules). You may touch any file. Do NOT run git commands. Gate output:\n${gates.report}\n\nTask context:\n${TASK}`,
      { label: 'fix:gates', phase: 'Verify', effort: 'high' })
    if (gateFix) fixReports.push(gateFix)
  }
  finalGates = (await runGates('gates:final')) || { passed: false, report: 'final gate-runner agent failed — verify manually' }
}

return {
  items: done.map(({ item, report }) => ({ title: item.title, files: item.files, report })),
  failedItems,
  reviewsFlagged: broken.map(b => ({ title: b.item.title, issues: b.review.issues })),
  fixReports: fixReports.filter(Boolean),
  gates: finalGates,
  note: 'No commits or pushes were made — review the tree (including any failedItems, whose files may be half-written), then commit/PR in the main conversation.',
}
