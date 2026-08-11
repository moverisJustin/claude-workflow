---
name: bspec-doc
description: Author a specification document as a saved file in the standardized BSpec format (YAML-frontmatter Markdown) — a spec, PRD, product/feature spec, requirements doc, architecture/system/API/data/security spec, decision record (ADR), retrospective, or similar deliverable. Use whenever the user asks to write up, draft, or create such a document so specs stay consistent across the company. NOT for ephemeral plan-mode planning or a quick verbal outline.
allowed-tools: Read, Write, Edit, Bash(bash ~/.claude/scripts/bspec-validate.sh *), Bash(bash .claude/scripts/bspec-validate.sh *)
---

# BSpec Doc

Author formal specification documents in the **BSpec** format — one shared,
company-wide standard so specs "talk across the company." Fires whenever you're
asked to write a spec / PRD / feature / requirements / architecture / decision
doc as a **saved file**. You (Claude) author the document directly and then
validate it offline with `bspec-validate.sh`.

> Skip this for ephemeral plan-mode planning or a quick verbal outline — it's
> only for a real document the user wants saved to a file.

## What a BSpec document is

One Markdown file per document: YAML frontmatter + Markdown body. Filename
`<TYPE>-<kebab-name>-v<version>.md`. Default location: `specs/` at the repo root
(create it if absent — or use the existing `documents/` directory if the repo is
already a `bspec init` project with a `manifest.json`).

```yaml
---
id: prd-checkout-001            # kebab-case, unique within the corpus
title: Checkout Requirements
type: PRD                        # a canonical BSpec type code (see table)
status: Draft                    # Draft | Review | Accepted | Deprecated
version: 1.0.0
owner: Product Team
domain: product
created: 2026-07-06
updated: 2026-07-06
related:                         # optional cross-links — each must resolve
  - msn-mission-001              # to a real doc id in the corpus
---

# Checkout Requirements

## Overview
...substantive Markdown body...
```

Relationship keys: `related`, `depends_on`, `enables`, `conflicts_with` — every
listed value must be the `id` of another doc in the corpus (the validator fails
on dangling links).

## Choosing the type

Pick the closest canonical code. Common ones for engineering + product work:

| Code | Use when writing… |
|------|-------------------|
| PRD  | product requirements / a product definition |
| FEA  | a feature specification |
| REQ  | functional / non-functional requirements |
| ARC  | system or solution architecture |
| SYS  | technical system specifications |
| API  | an API design (intent, not a generated reference) |
| DAT  | a data model / data architecture |
| SEC  | security architecture / controls |
| DEV  | a development / delivery plan |
| DEC  | a decision record (ADR) |
| RET  | a retrospective / postmortem |
| VSN / MSN / STR | vision / mission / strategy (business docs) |

Any code in the BSpec catalog is valid (the validator knows the full ~115-code
list). Use a better-fitting one if the table doesn't cover it; if genuinely
unsure, ask the user.

## Procedure

1. **Confirm it's a deliverable.** If the user just wants to think something
   through, don't create a file — this skill is for saved documents.
2. **Pick the type + a kebab name** → `specs/<TYPE>-<name>-v1.0.0.md`.
3. **Write the file**: the frontmatter above with *every* required field filled
   (`id`, `title`, `type`, `status`, `version`; plus `owner`, `domain`,
   `created`, `updated`), then **`## Brief` as the first section**, then a
   substantive Markdown body. Wire `related`/`depends_on`/`enables` to existing
   docs' real ids where relevant.

   ```markdown
   ## Brief
   **What this is.** [one sentence]
   **Why.** [the problem, one or two sentences]
   **What changes.** [three to six bullets]
   **What you must decide.** [open questions, or "Nothing."]
   **Risk.** [what could go wrong]
   ```

   A spec is read by people who were not in the room. The Brief is what they
   read first and often all they read, so it is written to the contract in
   `~/.claude/rules/writing.md`. The body below it carries the full technical
   detail and is exempt from the contract.
4. **Validate** (fix-loop until both pass):
   ```bash
   bash ~/.claude/scripts/bspec-validate.sh specs/<TYPE>-<name>-v1.0.0.md
   bash ~/.claude/scripts/ste-check.sh    specs/<TYPE>-<name>-v1.0.0.md
   ```
   Fall back to `bash .claude/scripts/…` if the global scripts aren't present.
   `bspec-validate` checks the frontmatter; `ste-check` checks the Brief and
   never reads the body. Fix every `ERROR` from either and re-run (up to ~3
   passes). `WARN` lines are advisory — address if easy.
5. **If no validator script exists at all**, still write the doc in this format,
   then tell the user it wasn't machine-validated (their install is incomplete —
   re-run `install.sh`).
6. **Report**: file path, type, validation result, and any cross-links created.

## Delegation

Substantial docs (anything beyond a one-page DEC) delegate the **draft** to the
`doc-generator` agent (sonnet): the brief must carry the Task Charter, the
chosen type code, the exact filename, and the frontmatter contract above. Main
Claude then reviews the draft, runs `bspec-validate.sh`, and fixes or accepts —
validation and acceptance are never delegated. Short DEC records stay
main-authored.

## Notes

- **Never** use `bspec chat` / `/generate` — it requires an external
  OpenRouter/OpenAI API key and routes through a non-Claude LLM. You are the
  author; write the doc yourself.
- The `bspec` **CLI is optional** — corpus tooling only (`bspec init | pack |
  open | query` over a `specs/` directory). Install it with
  `scripts/install-bspec-cli.sh` if you want to pack/query the whole corpus. It
  does **not** validate documents; `bspec-validate.sh` is the enforcement layer.
