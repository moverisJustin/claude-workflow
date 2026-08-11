# Writing

Every artifact a human reads opens with a **Brief**: a short block in plain English. The
technical body below it does not change, so other AI instances lose nothing.

**Binds**: the `## Brief` block, every request for a decision, the end-of-turn summary.
**Does not bind**: progress narration, the technical body of any document, code.

## The two blocks

```markdown
## Brief
**What this is.** One sentence.
**Why.** The problem, one or two sentences.
**What changes.** Three to six bullets.
**What you must decide.** The open questions, or "Nothing."
**Risk.** What could go wrong.
```

A **decision brief** replaces those fields whenever you need an answer. Use all six:
What I need (one sentence) / Why it is blocked / What I found (2-4 bullets, facts only) /
Options, each with its cost / What I recommend, with the reason / **If you say nothing**
(the default you take, or "I stop here").

Write it into `## Open decision` in `.claude/task-context.md` as you speak it. A brief that
lives only in the chat stream scrolls away, and the user often reads cold after an alert.
Move it to `## Decisions` when they answer.

## The rules

**Sentences.** 25 words maximum (STE 4.4, 8.6). 6 sentences maximum per paragraph, one
topic each (STE 6.2). One idea per sentence; split rather than subordinate (STE 4.1). A
vertical list for three or more parallel items (STE 4.3). Keep the articles (STE 4.5).

**Words.** One word, one meaning: pick a term, never swap in a synonym (STE 1.1). Define a
coined name on first use, then add it to `## Terms` (STE 1.5, 1.12). Prefer the short
common word. No em-dashes; use a period, comma, colon, or parentheses.

**Verbs.** Active voice, name the actor (STE 3.6). No gerund openers: "X does Y", not
"Adding X does Y" (STE 3.4). Simple tenses: "I added the file", not "I have added it"
(STE 3.1).

**Content.** Be self-contained: never "as discussed above", never a pronoun pointing at
something off screen. State the fact, then the consequence. If you do not know, say so and
say what would settle it.

## Do not use

leverage, utilize (or utilise), robust, seamless, comprehensive, delve, facilitate, in order
to, it is worth noting, it is important to note, crucially, moreover, furthermore, deep dive,
circle back, streamline, myriad, plethora, unlock, empower, elevate, a testament to, at the
end of the day, decisive, smoking gun, let me be clear, to be honest. Contractions of these
count ("it's worth noting"). No hedging chains, no tables for their own sake, no praise, no
restating what the reader just said.

`scripts/ste-check.sh` enforces this over the Brief block. Six checks block, the rest warn.

## Provenance

Our rules, informed by ASD-STE100 Simplified Technical English, Issue 9 (2025-01-15). Rule
numbers cite the source; your own copy is free from asd-ste100.org. No rule text or
dictionary content is reproduced: ASD bars reproduction without written authority and its
usage grant does not cover us. **We do not claim conformance** — that needs the ~900-word
approved dictionary, which we neither ship nor check.
