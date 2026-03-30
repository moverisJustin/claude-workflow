# Pattern Index

> Task-specific guides that grow from real work. Created by the GROW step in `/session-end`.
> The agent reads this index at session start (when routed), then loads only the matching pattern file.

## How Patterns Work
1. During `/session-end`, the GROW step asks: "Did this task reveal a reusable pattern?"
2. If yes, a pattern file is created in `patterns/` and registered here
3. On future sessions, the router loads this INDEX, matches by task type, and loads the relevant pattern
4. Patterns compound over time — each task makes the next one faster

## Registry

| Pattern | File | Task Signals | Last Updated |
|---------|------|-------------|-------------|
<!-- Example entries (uncomment and customize for your project):
| Add API endpoint | patterns/add-api-endpoint.md | api, endpoint, route | 2026-03-28 |
| Debug pipeline | patterns/debug-pipeline.md | debug, pipeline, stream | 2026-03-25 |
| Add database migration | patterns/add-migration.md | migration, schema, database | 2026-03-20 |
| Write integration test | patterns/write-integration-test.md | test, integration, e2e | 2026-03-18 |
-->

## Pattern File Template
When creating a new pattern, use this structure:
```markdown
# Pattern: [Name]

## When to Use
[1 sentence — what task type triggers this pattern]

## Steps
1. [Step-by-step guide for the task]
2. ...

## Conventions
- [Project-specific rules that apply to this task type]

## Common Mistakes
- [Things that have gone wrong before with this task type]

## Verify
- [ ] [Checklist to confirm the task was done correctly]
```
