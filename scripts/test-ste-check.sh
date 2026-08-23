#!/usr/bin/env bash
# test-ste-check.sh — regression tests for scripts/ste-check.sh
#
# ste-check IS the enforcement layer behind rules/writing.md, so a silent
# regression turns the writing contract back into a suggestion. Two of these
# cases exist because the checker false-positived on its own branch charter:
# the five field lines of a correct Brief merged into one 11-sentence
# "paragraph", and "Nothing." tripped the gerund-opener check.
#
# Pure bash 3.2, no deps beyond python3.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/ste-check.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

N=0
newfile() { N=$((N + 1)); F="$TMP/c$N.md"; }

# A Brief that must always pass. Every failing case below is this, minus one thing.
clean_brief() {
  cat > "$1" <<'EOF'
# Doc

## Brief
**What this is.** A checker for the writing contract.
**Why.** Prose that nothing checks is a suggestion, not a contract.
**What changes.** The gate rejects a Brief with a long sentence.
**What you must decide.** Nothing.
**Risk.** The checker could be noisy.

## Body
Anything at all goes here. This sentence is deliberately very long indeed, running well past
the twenty five word limit that the contract sets, because the body is exempt from the rule.
EOF
}

echo "ste-check regression tests"

# 1. A clean Brief passes, and the technical body is NOT checked.
newfile; clean_brief "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && echo "$OUT" | grep -q '0 error(s), 0 warning(s)'; } \
  && ok "clean Brief passes and the body is exempt" \
  || no "clean Brief passes (rc=$RC): $OUT"

# 2. REGRESSION: the five field lines must not merge into one paragraph.
#    Before the fix this reported '11 sentences in one paragraph'.
newfile; clean_brief "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'paragraph-too-long' \
  && no "regression: correct Brief fields merged into a paragraph" \
  || ok "Brief field lines are discrete, not one paragraph"

# 3. REGRESSION: 'Nothing.' is not a gerund opener.
newfile; clean_brief "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'gerund-opener' \
  && no "regression: 'Nothing.' flagged as a gerund opener" \
  || ok "'Nothing.' is not treated as a gerund"

# 4. ERROR: missing Brief block.
newfile
printf '# Doc\n\n## Body\nText.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'brief-missing'; } \
  && ok "missing Brief block is an error" || no "missing Brief (rc=$RC): $OUT"

# 5. --allow-missing skips a file with no Brief instead of failing.
OUT="$(bash "$CHECK" --allow-missing "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'skipped'; } \
  && ok "--allow-missing skips a Brief-less file" \
  || no "--allow-missing (rc=$RC): $OUT"

# 6. ERROR: a required field is absent.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** A thing.
**Why.** A reason.
**What changes.** One bullet.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "field-missing"; } \
  && ok "absent Brief field is an error" || no "field-missing (rc=$RC): $OUT"

# 7. ERROR: sentence over 25 words, and the finding carries a split suggestion.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** This one sentence runs on for a very long time indeed, and it keeps going
well past the limit that the writing contract sets for any sentence in a Brief block.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'sentence-too-long'; } \
  && ok "over-long sentence is an error" || no "sentence-too-long (rc=$RC): $OUT"
echo "$OUT" | grep -q -- '->' \
  && ok "over-long sentence carries a suggested rewrite" \
  || no "no suggestion printed for sentence-too-long"

# 8. ERROR: paragraph over 6 sentences (real prose, not field lines).
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** A thing.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.

One. Two. Three. Four. Five. Six. Seven.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'paragraph-too-long'; } \
  && ok "seven-sentence paragraph is an error" \
  || no "paragraph-too-long (rc=$RC): $OUT"

# 9. ERROR: a do-not-use phrase, with its substitute in the suggestion.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** We leverage the cache.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'banned-phrase'; } \
  && ok "do-not-use phrase is an error" || no "banned-phrase (rc=$RC): $OUT"
echo "$OUT" | grep -q "use 'use'" \
  && ok "banned phrase suggests its substitute" || no "no substitute suggested"

# 10. ERROR: unfilled template text, but a checkbox is not template text.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** [describe the thing]
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.
- [ ] this checkbox must not count as a placeholder
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && [ "$(echo "$OUT" | grep -c 'placeholder')" -eq 1 ]; } \
  && ok "placeholder is an error, checkbox is not" \
  || no "placeholder (rc=$RC): $OUT"

# 11. WARN: em-dash, passive voice, present perfect, off-screen reference.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** A thing — with an em-dash.
**Why.** The file was created by the script.
**What changes.** I have added the file.
**What you must decide.** As discussed above, nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "warnings alone do not fail the run" || no "warnings failed (rc=$RC)"
for w in em-dash passive-voice present-perfect not-self-contained; do
  echo "$OUT" | grep -q "$w" && ok "warns: $w" || no "missing warning: $w"
done

# 12. WARN: a coined name absent from ## Terms, and none when it is registered.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** The Widget Registry holds it.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.

## Terms
- **Other Thing** - something else
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'unregistered-term' \
  && ok "unregistered coined name warns" || no "no unregistered-term warning"

newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** The Widget Registry holds it.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.

## Terms
- **Widget Registry** - the store of widgets
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'unregistered-term' \
  && no "registered term still warned" || ok "registered term does not warn"

# 13. No ## Terms section at all is a vacuous pass, never a defect.
newfile; clean_brief "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'unregistered-term' \
  && no "file without ## Terms produced a term warning" \
  || ok "absent ## Terms is a vacuous pass"

# 14. An `## Open decision` of 'None.' is not checked as a decision brief.
newfile
clean_brief "$F"; printf '\n## Open decision\nNone.\n' >> "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'What I need'; } \
  && ok "'Open decision: None.' is not checked" \
  || no "None. was checked as a decision brief (rc=$RC): $OUT"

# 15. A real Open decision must carry all six decision-brief fields.
newfile
clean_brief "$F"
cat >> "$F" <<'EOF'

## Open decision
**What I need.** Pick a cache backend.
**Why it is blocked.** The writer cannot ship until you pick one.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'If you say nothing'; } \
  && ok "incomplete decision brief is an error" \
  || no "decision-brief fields (rc=$RC): $OUT"

# 16. Fence awareness: a '## ' inside a fenced block is not a heading.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** A thing.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.

```markdown
## Body
This fenced sentence is far longer than twenty five words and it must not be checked at all,
because a heading inside a fence is not a heading and this text is not part of the Brief.
```
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "fenced content is not parsed as prose or headings" \
  || no "fence handling (rc=$RC): $OUT"

# 17. --warn-only never fails, even with errors present.
newfile
printf '# Doc\n\n## Body\nText.\n' > "$F"
OUT="$(bash "$CHECK" --warn-only "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'not failing'; } \
  && ok "--warn-only reports errors without failing" \
  || no "--warn-only (rc=$RC): $OUT"

# 18. Bad usage exits 2.
OUT="$(bash "$CHECK" 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && ok "no target exits 2" || no "no target (rc=$RC)"
OUT="$(bash "$CHECK" --nope "$F" 2>&1)"; RC=$?
[ "$RC" -eq 2 ] && ok "unknown option exits 2" || no "unknown option (rc=$RC)"

# 19. A directory target checks every *.md under it.
newfile; D="$TMP/dir"; mkdir -p "$D"; clean_brief "$D/a.md"; clean_brief "$D/b.md"
OUT="$(bash "$CHECK" "$D" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && echo "$OUT" | grep -q '2 file(s)'; } \
  && ok "directory target sweeps every *.md" || no "directory sweep (rc=$RC): $OUT"

# 20. --quiet suppresses warnings but keeps errors and the summary.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** A thing — with an em-dash.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" --quiet "$F" 2>&1)"
{ ! echo "$OUT" | grep -q 'WARNINGS'; } && echo "$OUT" | grep -q 'ste-check:' \
  && ok "--quiet hides warnings, keeps the summary" || no "--quiet: $OUT"

# 20b. REGRESSION: an -en/-ed ADJECTIVE after a copula is not passive voice.
#      "are open" tripped the check while writing this branch's own DEC doc.
#      Short words ("is red", "are ten") matched too, via \w+ed / \w+en.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** Two assumptions are open.
**Why.** The count is seven and the door is red.
**What changes.** The list is even.
**What you must decide.** Nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'passive-voice' \
  && no "adjective after a copula flagged as passive: $OUT" \
  || ok "-en/-ed adjectives are not passive voice"

# 20c. A genuine passive is still caught after that fix.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** The file is created by the script.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'passive-voice' \
  && ok "a real passive is still caught" || no "real passive missed: $OUT"

# 20d. REGRESSION: a SECOND `## Brief` in one file must also be checked.
#      get_section returned only the first match, so a banned phrase or a
#      missing field in a later Brief passed clean. A PR body assembled from
#      parts is the realistic way to end up with two.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** A thing.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.

## Body
Text.

## Brief
**What this is.** We leverage the cache here.
**Why.** A reason.
**What changes.** One bullet.
**What you must decide.** Nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'banned-phrase'; } \
  && ok "a second ## Brief block is checked too" \
  || no "second Brief went unchecked (rc=$RC): $OUT"

# 21. --stdin reads the caller's stdin, not the heredoc that carries the program.
#     `python3 -` consumes stdin for the program itself, so the wrapper has to
#     capture it first. Without that, every --stdin run reported brief-missing.
newfile; clean_brief "$F"
OUT="$(bash "$CHECK" --stdin '<plan>' < "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'brief-missing'; } \
  && ok "--stdin reads piped markdown" || no "--stdin (rc=$RC): $OUT"

# 22. --stdin still reports a genuine fault, and labels it with the given name.
OUT="$(printf '# x\n\n## Body\ntext\n' | bash "$CHECK" --stdin '<plan>' 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q '<plan>:1'; } \
  && ok "--stdin reports faults under its label" || no "--stdin fault (rc=$RC): $OUT"

# ---------------------------------------------------------------------------
# Findings from the Codex adversarial review of the merged #39. Every one was
# reproduced against bd256f1 before it was fixed; each case below is that
# reproduction, inverted.
# ---------------------------------------------------------------------------

# C1. `## Open decision` must not suppress brief-missing.
newfile; printf '## Open decision\nNone.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'brief-missing'; } \
  && ok "an Open-decision-only file still reports brief-missing" \
  || no "C1 (rc=$RC): $OUT"

# C2. One prose sentence naming every field does NOT satisfy the fields.
newfile
printf '## Brief\nWhat this is, why, what changes, what you must decide, and risk.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'field-missing'; } \
  && ok "prose naming the fields does not satisfy them" || no "C2 (rc=$RC): $OUT"

# C3. Five bare labels with no content are errors, not a pass.
newfile
printf '## Brief\n**What this is.**\n**Why.**\n**What changes.**\n**What you must decide.**\n**Risk.**\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'no content'; } \
  && ok "empty Brief labels are errors" || no "C3 (rc=$RC): $OUT"

# C3b. A label heading a bullet list IS content.
newfile
cat > "$F" <<'EOF'
## Brief
**What this is.** A thing.
**Why.** A reason.
**What changes.**
- first
- second
- third
**What you must decide.** Nothing.
**Risk.** Low.
EOF
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "a label heading a bullet list counts as content" \
  || no "C3b (rc=$RC): $OUT"

# C4. A four-backtick fence must not close on a three-backtick example inside it.
newfile
printf '# x\n\n````\n```\n````\n\n## Brief\n**What this is.** A.\n**Why.** R.\n**What changes.** B.\n**What you must decide.** Nothing.\n**Risk.** Low.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q 'brief-missing'; } \
  && ok "nested fences of different lengths track correctly" || no "C4 (rc=$RC): $OUT"

# C5. A list marker is not a word: a 25-word bullet is 25, not 26.
newfile
printf '## Brief\n**What this is.** A.\n**Why.** R.\n**What changes.**\n- one two three four five six seven eight nine ten one two three four five six seven eight nine ten aa bb cc dd ee\n**What you must decide.** Nothing.\n**Risk.** Low.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "the list marker is not counted as a word" || no "C5 (rc=$RC): $OUT"

# C5b. ...and a gerund opener in a bullet is still caught.
newfile
printf '## Brief\n**What this is.** A.\n**Why.** R.\n**What changes.**\n- Adding the file fixes the bug.\n- second\n- third\n**What you must decide.** Nothing.\n**Risk.** Low.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"
echo "$OUT" | grep -q 'gerund-opener' \
  && ok "a gerund opener inside a bullet is still caught" || no "C5b: $OUT"

# C6. Reference-style links are not placeholders.
newfile
printf '## Brief\n**What this is.** A [Migration Guide][guide].\n**Why.** R.\n**What changes.** B.\n**What you must decide.** Nothing.\n**Risk.** Low.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "reference-style links are not placeholders" || no "C6 (rc=$RC): $OUT"

# C7. A banned word inside a code span is code, not prose.
newfile
printf '## Brief\n**What this is.** The API keeps `utilize()` for compatibility.\n**Why.** R.\n**What changes.** B.\n**What you must decide.** Nothing.\n**Risk.** Low.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "a banned word in a code span does not block" || no "C7 (rc=$RC): $OUT"

# C7b. ...but the same word in prose still blocks.
newfile
printf '## Brief\n**What this is.** We utilize the cache.\n**Why.** R.\n**What changes.** B.\n**What you must decide.** Nothing.\n**Risk.** Low.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
{ [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'banned-phrase'; } \
  && ok "a banned word in prose still blocks" || no "C7b (rc=$RC): $OUT"

# C8. A sentence boundary after a closing quote is a boundary.
newfile
printf '## Brief\n**What this is.** The user said "Stop." The plan then does one two three four five six seven eight nine ten eleven twelve.\n**Why.** R.\n**What changes.** B.\n**What you must decide.** Nothing.\n**Risk.** Low.\n' > "$F"
OUT="$(bash "$CHECK" "$F" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "a closing quote does not merge two sentences" || no "C8 (rc=$RC): $OUT"

# C9. Irregular passives and intervening adverbs are caught.
for s in 'The cache was built by the installer.' 'The file was already created by the script.'; do
  newfile
  printf '## Brief\n**What this is.** %s\n**Why.** R.\n**What changes.** B.\n**What you must decide.** Nothing.\n**Risk.** Low.\n' "$s" > "$F"
  echo "$(bash "$CHECK" "$F" 2>&1)" | grep -q 'passive-voice' \
    && ok "passive caught: ${s:0:34}..." || no "passive missed: $s"
done

# C10. The blocking word list must not exceed the documented contract.
DRIFT="$(python3 - <<'PY'
import re
src = open("scripts/ste-check.sh").read()
ban = re.search(r'^BANNED = \{(.*?)^\}', src, re.S | re.M).group(1)
keys = set(re.findall(r'"([^"]+)":', ban))
# The chat-only blocking lists ride the same guarantee: ste-check may only
# block on a phrase that rules/writing.md actually names.
for name in ("CHAT_OPENERS", "CHAT_CLOSERS"):
    block = re.search(r'^%s = \[(.*?)^\]' % name, src, re.S | re.M).group(1)
    keys |= set(re.findall(r'"([^"]+)"', block))
# writing.md is line-wrapped, so collapse whitespace before comparing.
doc = re.sub(r"\s+", " ", open("rules/writing.md").read().lower())

def listed(k):
    k = k.lower()
    if k in doc:
        return True
    # The contract says "Contractions count", so a contracted form is covered
    # by its expansion rather than needing its own entry.
    expanded = k.replace("it's", "it is").replace("n't", " not")
    return expanded in doc

print(" ".join(sorted(k for k in keys if not listed(k))))
PY
)"
[ -z "$DRIFT" ] && ok "every blocking phrase appears in rules/writing.md" \
  || no "blocking phrases absent from the contract: $DRIFT"

# C11. --stdin must match the flag exactly, not as a substring of a filename.
newfile; clean_brief "$F"
SPACED="$TMP/a --stdin b.md"; cp "$F" "$SPACED"
OUT="$(bash "$CHECK" "$SPACED" < /dev/null 2>&1)"; RC=$?
{ [ "$RC" -eq 0 ] && echo "$OUT" | grep -q '1 file(s)'; } \
  && ok "a filename containing ' --stdin ' is a path, not the flag" \
  || no "C11 (rc=$RC): $OUT"

# --- chat mode (--chat) ------------------------------------------------------
# rules/writing.md ## The chat stream governs an ANSWER, which has no Brief.

# `|| true` is load-bearing. The suite runs under `set -o pipefail`, so without
# it `chat X | grep -q closer` inherits ste-check's exit 1 and the test reads as
# a miss even when grep matched.
chat() { printf '%b' "$1" | bash "$CHECK" --chat --stdin chat 2>&1 || true; }
chat_rc() { printf '%b' "$1" | bash "$CHECK" --chat --stdin chat >/dev/null 2>&1; echo $?; }

# C12. A clean answer passes, and no Brief-shaped check fires on it.
CLEAN='Fixed at src/auth.ts:42. The token check read the wrong header.\n\nNext: run npm test.\n'
OUT="$(chat "$CLEAN")"; RC="$(chat_rc "$CLEAN")"
{ [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -qE 'brief-missing|field-missing|placeholder'; } \
  && ok "chat: a clean answer passes with no Brief-shaped findings" \
  || no "C12 (rc=$RC): $OUT"

# C13. A preamble opener blocks.
chat 'Let me take a look at that.\n\nThe fix is at src/auth.ts:42.\n' | grep -q 'preamble' \
  && ok "chat: a 'Let me' opener blocks" || no "C13: preamble missed"

# C14. A closing pleasantry blocks.
chat 'The fix is at src/auth.ts:42.\n\nHope this helps!\n' | grep -q 'closer' \
  && ok "chat: a 'Hope this helps' closer blocks" || no "C14: closer missed"

# C15. An opener counts only on the FIRST line, a closer only on the LAST.
MID='The fix is at src/auth.ts:42.\nHope this helps with the header.\nRun npm test now.\n'
[ "$(chat_rc "$MID")" -eq 0 ] \
  && ok "chat: a closer phrase mid-answer does not block" \
  || no "C15: mid-answer phrase blocked: $(chat "$MID")"

# C16. A bare coined name warns and does NOT block.
BARE='The Plan Gate now blocks. Run the tests.\n'
{ chat "$BARE" | grep -q 'bare-coined-name' && [ "$(chat_rc "$BARE")" -eq 0 ]; } \
  && ok "chat: a bare coined name warns without blocking" || no "C16: $(chat "$BARE")"

# C16b. A glossed name is silent.
GLOSSED='The Plan Gate (it checks a plan before you approve it) now blocks. Run tests.\n'
chat "$GLOSSED" | grep -q 'bare-coined-name' \
  && no "C16b: a glossed name still warned" \
  || ok "chat: a glossed coined name is silent"

# C16c. A stoplisted proper noun never warns.
chat 'Claude Code writes the transcript. Run the tests.\n' | grep -q 'bare-coined-name' \
  && no "C16c: a stoplisted proper noun warned" \
  || ok "chat: a stoplisted proper noun is silent"

# C17. THE COLLISION REGRESSION. `CLOSERS` is the sentence splitter's
# closing-punctuation string. The chat list was first written as `CLOSERS` too,
# and the later definition silently won, so `closer` fired on any last line
# ending in a bracket. Renaming to CHAT_CLOSERS fixed it; this proves it stays.
PAREN='The fix is at src/auth.ts:42 (the header was wrong).\n'
[ "$(chat_rc "$PAREN")" -eq 0 ] \
  && ok "chat: a last line ending in ')' is not a closing pleasantry" \
  || no "C17: punctuation read as a closer: $(chat "$PAREN")"

# C18. No name may be assigned twice at the top level. C17 is one instance;
# this catches the next collision on a name nobody has thought of yet.
DUPES="$(grep -oE '^[A-Za-z_][A-Za-z0-9_]* *=[^=]' "$CHECK" \
         | sed 's/ *=.*//' | sort | uniq -d | tr '\n' ' ')"
[ -z "$DUPES" ] && ok "no top-level name in ste-check.sh is defined twice" \
  || no "defined twice, so the later one silently wins: $DUPES"

echo ""
echo "ste-check tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
