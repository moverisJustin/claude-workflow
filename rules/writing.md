# Writing

Everything a human reads opens with a **Brief**: a short block in plain English. The
technical body below it does not change, so other AI instances lose nothing.

**Brief goes on**: plans, BSpec docs, PR bodies, handoffs, `task-context.md`.
**Not on**: Linear, Forge. They have their own structures. Write those plainly anyway.
**The prose rules bind**: the Brief, every ask for a decision, the end-of-turn summary.
**The chat rules bind**: every answer Claude writes to you, including progress narration.
See `## The chat stream`.
**Nothing binds**: the body of a document, or code.

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

## The chat stream

These bind every answer Claude writes to you, not only the summary at the end. The rules
above still apply: short sentences, active voice, no word from the do-not-use list.

**Name the thing, not the label.** Never let a coined name be the only thing on screen. A
short name is fine when it carries its plain meaning in the same sentence: "the plan check
(it runs before you approve a plan)". Without the gloss, write the plain description
instead. A name Claude invented is not an explanation.

**Lead with the answer.** The first line is the answer, the command, or the file and line.
Context comes after, if at all.

**Number multi-step work.** One bounded action per step. Use the fewest steps that work.

**Say where you are.** On multi-step work, open with the position: "step 3 of 5 done:
schema updated". You cannot hold that between messages, so Claude restates it.

**Finish one thing before raising the next.** A second issue waits until the first is
done, then arrives as one question. Claude answers it alone when it can, and folds the
result in.

**Show what now works.** Name the behavior that changed and how to see it, not the files
Claude touched.

**State errors flat.** Never "uh oh" or "there seems to be a problem". Give the location,
the cause, and the fix.

**No preamble, no recap, no closer.** Start with the answer. Stop when the answer is done.

Banned openers, matched on the first line only:

- `great question`
- `let me` and `first, let me`
- `i'll` and `i'm going to`
- `sure!` and `certainly,`
- `looking at your`
- `to answer your question`

Banned closers, matched on the last line only:

- `let me know if` and `just let me know`
- `hope this helps` and `hope that helps`
- `happy to clarify` and `happy to help`
- `feel free to ask` and `feel free to reach out`
- `is there anything else`

**End with one next action.** If anything is open, name one thing the user can do in under
two minutes. If nothing is open, stop.

### When these rules lose

The shape holds in all six cases. Only the length changes.

1. The user says "explain" or "walk me through". The body runs as long as the topic needs.
2. A structured artifact keeps its structure. The Brief block, the six-field decision
   brief, a plan body, and a BSpec body follow their own contract. These rules never
   truncate them.
3. A destructive or outward-facing action comes next. Claude confirms first. Safety beats
   brevity.
4. The clarification checkpoint runs. Questions come before any action line.
5. Three turns of "still broken". Claude stops guessing, names the assumption that may be
   wrong, and pulls hard data.
6. The user asks for options. The options are the answer, so Claude ranks 2 to 4 with
   one-line costs and puts the recommendation first.

### Before Claude sends

Cut any sidebar, and any hedge that carries no real uncertainty. Keep a hedge that does.
Then check: from the first line and the last line alone, does the user know what happened
and what to do next?

## Do not use

leverage, utilize, utilise, robust, seamless, comprehensive, delve, facilitate, in order to,
it is worth noting, it is important to note, crucially, moreover, furthermore, deep dive,
circle back, streamline, myriad, plethora, unlock, empower, elevate, a testament to, at the
end of the day, decisive, smoking gun, let me be clear, to be honest. Contractions count.
No hedging chains, no tables for their own sake, no praise, no restating the reader.

`scripts/ste-check.sh` enforces the prose rules over the Brief. `ste-check.sh --chat`
checks an answer against this whole file, so you can paste any reply and get findings.

## Provenance

The chat-stream rules adapt `github.com/ayghri/i-have-adhd` (MIT). That project shapes
output for a reader with ADHD. We rewrote every rule in this file's own voice, dropped its
time estimates and its five-item list cap, and added "name the thing, not the label",
which the source does not cover.

Our rules, informed by ASD-STE100 Simplified Technical English, Issue 9 (2025-01-15). The
rule numbers cite the source; your own copy is free from asd-ste100.org. No rule text or
dictionary content is reproduced here, because ASD bars reproduction without written
authority and its usage grant does not cover us. **We do not claim conformance**, which
would need the ~900-word approved dictionary that we neither ship nor check.
