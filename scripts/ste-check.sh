#!/usr/bin/env bash
# ste-check.sh — enforce the writing contract on the Brief block.
#
# WHY THIS EXISTS: everything a human reads in this workflow (plans, specs, PR
# bodies, Linear issues, handoffs) is correct and thorough and hard to trace.
# ~/.claude/rules/writing.md fixes that with a short plain-English block at the
# top of each artifact. This is the enforcement layer. Prose in a rule file that
# nothing checks is a suggestion, not a contract — the same lesson recorded at
# scripts/hook-plan-gate.sh:5.
#
# SCOPE IS THE POINT: this reads ONLY the `## Brief` block and `## Open decision`.
# It never reads the technical body. That single decision is what keeps the
# false-positive rate low enough that the findings stay worth reading, and it is
# what the contract promises: plain summary on top, normal technical detail below.
#
# Every finding prints a suggested rewrite. A checker that says "sentence 3 is 41
# words" teaches you to ignore it. One that shows the 22-word version teaches you
# to write it.
#
# The rules derive from ASD-STE100 Simplified Technical English Issue 9. No rule
# text or dictionary content from that standard appears here — ASD bars
# reproduction without written authority. See rules/writing.md § Provenance.
#
# Usage:
#   ste-check.sh <file-or-dir> [more...]   check a file, or every *.md in a dir
#   ste-check.sh --stdin [label]           check markdown piped in on stdin
#   ste-check.sh --warn-only <target>      never fail; report and exit 0
#   ste-check.sh --allow-missing <target>  a file with no Brief block is skipped
#   ste-check.sh --quiet <target>          only print errors + the summary
#   ste-check.sh --list-checks             print every check id and exit
#
# --stdin exists for hook-plan-gate.sh: the ExitPlanMode payload carries the plan
# text inline as tool_input.plan (verified empirically — the payload has both
# `plan` and `planFilePath`), so the gate checks the text it was handed rather
# than racing a file read.
# Exit: 0 clean (warnings are non-fatal), 1 any error, 2 bad usage.

set -euo pipefail

# `python3 -` reads the PROGRAM from stdin via the heredoc below, so the program
# can never read the caller's stdin itself. Capture it here, before the heredoc
# redirect applies, and hand it over in the environment. Plans are a few KB; this
# is well inside ARG_MAX.
STE_STDIN=""
case " $* " in
  *" --stdin "*) STE_STDIN="$(cat)" ;;
esac
export STE_STDIN

exec python3 - "$@" <<'PY'
import sys, os, re, glob

# ---------------------------------------------------------------------------
# Contract constants. These mirror rules/writing.md; change both together.
# ---------------------------------------------------------------------------
MAX_SENTENCE_WORDS = 25          # writing.md Sentences, from STE 4.4 / 8.6
MAX_PARA_SENTENCES = 6           # writing.md Sentences, from STE 6.2

BRIEF_FIELDS = ["What this is.", "Why.", "What changes.",
                "What you must decide.", "Risk."]
DECISION_FIELDS = ["What I need.", "Why it is blocked.", "What I found.",
                   "Options.", "What I recommend.", "If you say nothing."]

# Our own list, not ASD's. Value is the substitute the finding suggests.
BANNED = {
    "leverage": "use", "utilize": "use", "utilise": "use",
    "robust": "say what it survives", "seamless": "say what it removes",
    "comprehensive": "say what it covers", "delve": "look at",
    "facilitate": "help", "in order to": "to",
    "it is worth noting": "(delete; just state it)",
    "it's worth noting": "(delete; just state it)",
    "it is important to note": "(delete; just state it)",
    "crucially": "(delete)", "moreover": "also", "furthermore": "also",
    "deep dive": "look closely", "circle back": "come back to",
    "streamline": "simplify", "myriad": "many", "plethora": "many",
    "unlock": "make possible", "empower": "let", "elevate": "improve",
    "at the end of the day": "(delete)", "decisive": "say what it decides",
    "smoking gun": "the evidence", "let me be clear": "(delete)",
    "to be honest": "(delete)", "a testament to": "shows",
}

NOT_SELF_CONTAINED = [
    "as discussed above", "as mentioned above", "as mentioned earlier",
    "as noted above", "per the above", "see above", "the aforementioned",
    "as described earlier", "as we discussed", "from earlier",
]

# Irregular past participles that a "have/has + X" test would otherwise miss,
# plus the -ed/-en regulars handled by the pattern.
IRREGULAR_PP = {
    "been", "done", "gone", "made", "run", "written", "taken", "given",
    "found", "built", "kept", "left", "sent", "put", "read", "set", "shown",
    "seen", "known", "become", "begun", "broken", "brought", "chosen", "come",
    "cut", "drawn", "driven", "fallen", "felt", "got", "gotten", "held", "hit",
    "lost", "meant", "met", "paid", "said", "sold", "spent", "stood", "told",
    "thought", "understood", "won", "let", "split",
}

# Words ending in -ed/-en that are not past participles. The passive and
# present-perfect tests look for "<copula> <word>ed|en", which otherwise fires on
# "are open" and "is even". A three-character minimum stem kills the short ones
# ("red", "ten", "men", "then", "open", "even"); this list covers the rest.
NOT_PARTICIPLES = {
    "open", "even", "seven", "often", "golden", "sudden", "wooden", "garden",
    "kitchen", "citizen", "oxygen", "hyphen", "listen", "happen", "sharpen",
    "hundred", "sacred", "naked", "wicked", "rugged", "biased",
}

# Words that end in -ing but are not gerunds. Without this, "Nothing." trips the
# gerund-opener check, and "Nothing." is the correct answer to a Brief's
# "What you must decide" field.
NOT_GERUNDS = {
    "nothing", "something", "anything", "everything", "thing", "things",
    "during", "string", "spring", "ring", "bring", "king", "sing", "wing",
    "morning", "evening", "ceiling", "willing", "sibling",
    "according", "regarding", "missing", "existing",
}

# Multi-word capitalized strings that are proper nouns, not coined terms.
TERM_STOPLIST = {
    "Claude Code", "Simplified Technical English", "Technical English",
    "Plain English", "Task Context", "Memory Bank", "Pull Request",
    "Open Decision", "Terms Register", "Issue 9", "Boris Build",
}

CHECKS = [
    ("brief-missing",     "error", "no `## Brief` block in the file"),
    ("field-missing",     "error", "a required Brief field is absent"),
    ("sentence-too-long", "error", "sentence over %d words" % MAX_SENTENCE_WORDS),
    ("paragraph-too-long","error", "paragraph over %d sentences" % MAX_PARA_SENTENCES),
    ("banned-phrase",     "error", "a phrase from the do-not-use list"),
    ("placeholder",       "error", "unfilled template text left in the block"),
    ("passive-voice",     "warn",  "passive construction; name the actor"),
    ("gerund-opener",     "warn",  "sentence opens with a gerund"),
    ("em-dash",           "warn",  "em-dash in the Brief"),
    ("not-self-contained","warn",  "points at something off screen"),
    ("present-perfect",   "warn",  "present perfect; use the simple past"),
    ("unregistered-term", "warn",  "coined name absent from `## Terms`"),
]

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
args = sys.argv[1:]
warn_only = quiet = allow_missing = use_stdin = False
targets = []
for a in args:
    if a == "--stdin":
        use_stdin = True
    elif a == "--warn-only":
        warn_only = True
    elif a in ("--quiet", "-q"):
        quiet = True
    elif a == "--allow-missing":
        allow_missing = True
    elif a == "--list-checks":
        for cid, sev, desc in CHECKS:
            print("%-20s %-6s %s" % (cid, sev, desc))
        sys.exit(0)
    elif a.startswith("-"):
        sys.stderr.write("ste-check: unknown option %s\n" % a)
        sys.exit(2)
    else:
        targets.append(a)

if not targets and not use_stdin:
    sys.stderr.write(
        "usage: ste-check.sh [--stdin] [--warn-only] [--allow-missing] "
        "[--quiet] <file-or-dir> [...]\n")
    sys.exit(2)

# path -> lines. stdin becomes a single pseudo-file keyed by its label.
sources = []
if use_stdin:
    label = targets[0] if targets else "<stdin>"
    sources.append((label, os.environ.get("STE_STDIN", "").splitlines()))
else:
    files = []
    for t in targets:
        if os.path.isdir(t):
            files.extend(sorted(glob.glob(os.path.join(t, "**", "*.md"),
                                          recursive=True)))
        elif os.path.exists(t):
            files.append(t)
        else:
            sys.stderr.write("ste-check: no such path: %s\n" % t)
            sys.exit(2)

# ---------------------------------------------------------------------------
# Section extraction — fence-aware, because a Brief may contain a fenced block
# and a column-0 '## ' inside a fence is not a heading. Same hazard the
# markdown-splitter lesson records and drift-check.sh:399 already handles.
# ---------------------------------------------------------------------------
def sections(lines):
    """Yield (heading_text, start_index, end_index) for column-0 '## ' headings."""
    fence = None
    heads = []
    for i, ln in enumerate(lines):
        m = re.match(r"^(```+|~~~+)", ln)
        if m:
            tok = m.group(1)[0] * 3
            if fence is None:
                fence = tok
            elif fence == tok:
                fence = None
            continue
        if fence is None and re.match(r"^## +\S", ln):
            heads.append((ln[3:].strip(), i))
    for n, (title, start) in enumerate(heads):
        end = heads[n + 1][1] if n + 1 < len(heads) else len(lines)
        yield title, start + 1, end

def get_section(lines, name):
    for title, s, e in sections(lines):
        if title.lower() == name.lower():
            return lines[s:e]
    return None

# ---------------------------------------------------------------------------
# Prose extraction from a block: drop fences, tables, headings; unwrap the bold
# field labels so `**Why.**` does not read as a one-word sentence.
# ---------------------------------------------------------------------------
LABEL_RE = re.compile(r"^\s*(?:[-*]\s+)?\*\*([^*]+?)\*\*\s*")

def clean_line(ln):
    ln = LABEL_RE.sub("", ln)                       # strip a leading bold label
    ln = re.sub(r"`[^`]*`", "CODE", ln)             # code spans are not prose
    ln = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", ln)  # links -> their text
    ln = re.sub(r"\*\*|__|\*|_", "", ln)            # remaining emphasis
    return ln.rstrip()

def prose_units(block):
    """
    Return (units, paragraphs).
      units      = [(kind, text, lineno)] one entry per LOGICAL unit — a Brief
                   field, a list item, or a paragraph. Soft-wrapped source lines
                   are joined into the unit they continue, because markdown wraps
                   sentences at the column limit and a per-line check misses
                   almost every real over-long sentence.
      paragraphs = [[text,...]] the flowing-prose units only. Lists and field
                   lines are exempt from the 6-sentence rule: they are discrete
                   statements, and STE 4.3 actively wants a vertical list.
    """
    units, paragraphs, current = [], [], []
    buf = None            # (kind, text, lineno) being accumulated
    fence = None

    def flush_buf():
        nonlocal buf
        if buf is not None:
            units.append(buf)
            if buf[0] == "para":
                current.append(buf[1])
            buf = None

    def flush_para():
        if current:
            paragraphs.append(list(current))
            del current[:]

    for i, raw in enumerate(block):
        m = re.match(r"^(```+|~~~+)", raw)
        if m:
            tok = m.group(1)[0] * 3
            fence = tok if fence is None else (None if fence == tok else fence)
            flush_buf(); flush_para()
            continue
        if fence is not None:
            continue
        s = raw.strip()
        if not s or s.startswith("|") or s.startswith("#") or set(s) <= set("-=*_"):
            flush_buf(); flush_para()
            continue

        is_list = bool(re.match(r"^\s*(?:[-*+]\s|\d+[.)]\s)", raw))
        # A Brief field line (`**What this is.** ...`) is a discrete statement,
        # not part of a running paragraph. Without this, the five field lines of
        # a perfectly correct Brief merge into one 11-sentence "paragraph" and
        # every Brief in the repo fails paragraph-too-long. Caught by running
        # this checker against its own branch charter.
        is_field = bool(LABEL_RE.match(raw))
        text = clean_line(raw)
        if not text.strip():
            continue

        if is_list or is_field or buf is None:
            flush_buf()
            if is_list or is_field:
                flush_para()
            buf = ("list" if is_list else "para", text.strip(), i)
        else:
            buf = (buf[0], (buf[1] + " " + text.strip()).strip(), buf[2])

    flush_buf(); flush_para()
    return units, paragraphs

ABBREV = {"e.g", "i.e", "etc", "vs", "cf", "no", "fig", "approx", "min", "max"}

def split_sentences(text):
    out, buf = [], ""
    i = 0
    while i < len(text):
        ch = text[i]
        buf += ch
        if ch in ".!?":
            nxt = text[i + 1: i + 2]
            prev_word = re.split(r"[\s(]", buf.strip())[-1].rstrip(".!?").lower()
            is_decimal = ch == "." and nxt.isdigit()
            is_abbrev = ch == "." and prev_word in ABBREV
            if not is_decimal and not is_abbrev and (nxt == "" or nxt.isspace()):
                out.append(buf.strip()); buf = ""
        i += 1
    if buf.strip():
        out.append(buf.strip())
    return [s for s in out if s]

def word_count(sentence):
    return len([w for w in re.split(r"\s+", sentence.strip()) if w])

# ---------------------------------------------------------------------------
# Suggestions. Every finding carries one.
# ---------------------------------------------------------------------------
# Tier 1 is a punctuated clause boundary, which always splits cleanly. Tier 2 is
# a bare conjunction, tried only when tier 1 finds nothing — it splits a run-on
# that never reached for a comma, which is the common shape of an over-long
# sentence.
SPLIT_POINTS = [", and ", ", but ", ", so ", "; ", ", which ", ", because ",
                ", then ", ", while ", ", although "]
SPLIT_FALLBACK = [" and then ", " and ", " but ", " so that ", " because ",
                  " while ", " which "]

def _nearest(sentence, tokens):
    best, best_dist = None, None
    mid = len(sentence) / 2.0
    for token in tokens:
        idx = sentence.find(token)
        while idx != -1:
            dist = abs(idx - mid)
            if best_dist is None or dist < best_dist:
                best, best_dist = (idx, token), dist
            idx = sentence.find(token, idx + 1)
    return best

def suggest_split(sentence):
    best = _nearest(sentence, SPLIT_POINTS) or _nearest(sentence, SPLIT_FALLBACK)
    if best is None:
        return ("no clean split point; cut the qualifiers, or move the detail "
                "below the Brief")
    idx, token = best
    head = sentence[:idx].strip().rstrip(",;")
    tail = sentence[idx + len(token):].strip()
    if not head or not tail:
        return "cut the qualifiers, or move the detail below the Brief"
    tail = tail[0].upper() + tail[1:]
    return "%s. %s" % (head, tail)

def suggest_degerund(sentence):
    m = re.match(r"^(\w+ing)\b\s+(.*)$", sentence)
    if not m:
        return "start with the actor, not the -ing form"
    return "start with the actor: '%s ...' becomes '<actor> %ss ...'" % (
        m.group(1), m.group(1)[:-3])

def suggest_simple_past(sentence):
    m = re.search(r"\b(have|has)\s+(\w+)\b", sentence, re.I)
    if not m:
        return "use the simple past"
    return "drop '%s': '%s %s' becomes '%s'" % (
        m.group(1), m.group(1), m.group(2), m.group(2))

# ---------------------------------------------------------------------------
# The checks
# ---------------------------------------------------------------------------
def check_block(block, kind, terms, findings, offset, path):
    """kind is 'brief' or 'decision'. offset maps block index -> file line."""
    def add(cid, sev, line_idx, message, suggestion):
        findings.append({
            "path": path, "line": offset + line_idx + 1, "id": cid,
            "sev": sev, "msg": message, "fix": suggestion,
        })

    body = "\n".join(block)
    low = body.lower()

    # -- field-missing (error) ------------------------------------------------
    want = DECISION_FIELDS if kind == "decision" else BRIEF_FIELDS
    for field in want:
        if field.lower().rstrip(".") not in low:
            add("field-missing", "error", 0,
                "Brief field missing: '%s'" % field,
                "add a line: **%s** <one sentence>" % field)

    # -- placeholder (error) --------------------------------------------------
    for i, raw in enumerate(block):
        if re.match(r"^\s*-\s*\[[ x~]\]", raw):     # a checkbox is not a placeholder
            continue
        stripped = re.sub(r"`[^`]*`", "", raw)
        m = re.search(r"\[([A-Za-z][^\]]{2,})\](?!\()", stripped)
        if m:
            add("placeholder", "error", i,
                "template text left in the Brief: [%s]" % m.group(1)[:40],
                "replace it with the real content, or delete the line")
        m2 = re.search(r"<([a-z][a-z0-9 _-]{2,})>", stripped)
        if m2:
            add("placeholder", "error", i,
                "template text left in the Brief: <%s>" % m2.group(1)[:40],
                "replace it with the real content, or delete the line")

    units, paragraphs = prose_units(block)

    # -- sentence-too-long (error) + per-sentence warnings --------------------
    for kind_u, text, idx in units:
        for sent in split_sentences(text):
            n = word_count(sent)
            if n > MAX_SENTENCE_WORDS:
                add("sentence-too-long", "error", idx,
                    "%d words (limit %d): %s" % (n, MAX_SENTENCE_WORDS,
                                                 sent[:70] + ("..." if len(sent) > 70 else "")),
                    suggest_split(sent))
            gm = re.match(r"^(\w+ing)\b", sent)
            if gm and gm.group(1).lower() not in NOT_GERUNDS:
                add("gerund-opener", "warn", idx,
                    "gerund opener: %s" % sent[:60], suggest_degerund(sent))
            m = re.search(r"\b(have|has)\s+(\w{3,}(?:ed|en))\b", sent, re.I)
            if m and m.group(2).lower() in NOT_PARTICIPLES:
                m = None
            if not m:
                m = re.search(r"\b(have|has)\s+(%s)\b" % "|".join(sorted(IRREGULAR_PP)),
                              sent, re.I)
            if m:
                add("present-perfect", "warn", idx,
                    "present perfect: '%s %s'" % (m.group(1), m.group(2)),
                    suggest_simple_past(sent))
            pm = re.search(r"\b(?:is|are|was|were|be|been|being)\s+(\w{3,}(?:ed|en))\b",
                           sent, re.I)
            if pm and pm.group(1).lower() not in NOT_PARTICIPLES:
                add("passive-voice", "warn", idx,
                    "passive: '%s'" % pm.group(0),
                    "name the actor: who does the '%s'?" % pm.group(1).lower())

    # -- paragraph-too-long (error) ------------------------------------------
    for para in paragraphs:
        joined = " ".join(para)
        sents = split_sentences(joined)
        if len(sents) > MAX_PARA_SENTENCES:
            add("paragraph-too-long", "error", 0,
                "%d sentences in one paragraph (limit %d)" % (len(sents),
                                                              MAX_PARA_SENTENCES),
                "split it, or turn the list of points into a vertical list")

    # -- banned-phrase (error) ------------------------------------------------
    for phrase, better in BANNED.items():
        for m in re.finditer(r"(?<![A-Za-z])%s(?![A-Za-z])" % re.escape(phrase), low):
            line_idx = body.count("\n", 0, m.start())
            add("banned-phrase", "error", line_idx,
                "do-not-use phrase: '%s'" % phrase,
                "use '%s'" % better)

    # -- em-dash (warn) -------------------------------------------------------
    for i, raw in enumerate(block):
        if "—" in raw:
            add("em-dash", "warn", i, "em-dash in the Brief",
                "use a period, comma, colon, or parentheses")

    # -- not-self-contained (warn) -------------------------------------------
    for phrase in NOT_SELF_CONTAINED:
        idx = low.find(phrase)
        if idx != -1:
            add("not-self-contained", "warn", body.count("\n", 0, idx),
                "points off screen: '%s'" % phrase,
                "restate the thing itself; the reader may not have it on screen")

    # -- unregistered-term (warn) --------------------------------------------
    if terms is not None:
        seen = set()
        for _k, text, idx in units:
            for m in re.finditer(r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b", text):
                term = m.group(1)
                # A sentence-initial determiner is capitalized too, so "The
                # Widget Registry" matches where only "Widget Registry" is the
                # coined name. Without this strip, a correctly registered term
                # still warns.
                term = re.sub(r"^(?:The|A|An|This|That|These|Those|Its|Our|Your|My)\s+",
                              "", term)
                if " " not in term or term in TERM_STOPLIST or term in seen:
                    continue
                if term.lower() in terms:
                    continue
                seen.add(term)
                add("unregistered-term", "warn", idx,
                    "coined name not in `## Terms`: '%s'" % term,
                    "add: - **%s** - <one-sentence definition>" % term)

def read_terms(lines):
    block = get_section(lines, "Terms")
    if block is None:
        return None
    found = set()
    for ln in block:
        m = re.match(r"^\s*-\s*\*\*(.+?)\*\*", ln)
        if m:
            found.add(m.group(1).strip().lower())
    return found

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
findings, checked, skipped = [], 0, 0

if not use_stdin:
    for path in files:
        try:
            with open(path, errors="ignore") as fh:
                sources.append((path, fh.read().splitlines()))
        except OSError as exc:
            sys.stderr.write("ste-check: cannot read %s: %s\n" % (path, exc))

for path, lines in sources:
    brief = get_section(lines, "Brief")
    decision = get_section(lines, "Open decision")
    terms = read_terms(lines)

    if brief is None and decision is None:
        if allow_missing:
            skipped += 1
            continue
        findings.append({
            "path": path, "line": 1, "id": "brief-missing", "sev": "error",
            "msg": "no `## Brief` block",
            "fix": "add one; the five fields are in rules/writing.md",
        })
        checked += 1
        continue

    checked += 1
    if brief is not None:
        start = next(s for t, s, _e in sections(lines) if t.lower() == "brief")
        check_block(brief, "brief", terms, findings, start, path)
    if decision is not None:
        body = "\n".join(decision).strip()
        if body and body.lower() not in ("none.", "none", "n/a"):
            start = next(s for t, s, _e in sections(lines)
                         if t.lower() == "open decision")
            check_block(decision, "decision", terms, findings, start, path)

errors = [f for f in findings if f["sev"] == "error"]
warns = [f for f in findings if f["sev"] == "warn"]

def emit(f):
    print("  %s:%d  %-19s %s" % (f["path"], f["line"], f["id"], f["msg"]))
    print("      -> %s" % f["fix"])

if errors:
    print("ERRORS")
    for f in errors:
        emit(f)
if warns and not quiet:
    if errors:
        print("")
    print("WARNINGS")
    for f in warns:
        emit(f)

summary = "ste-check: %d file(s), %d error(s), %d warning(s)" % (
    checked, len(errors), len(warns))
if skipped:
    summary += ", %d skipped (no Brief)" % skipped
if warn_only and errors:
    summary += " [--warn-only: not failing]"
print(("\n" if (errors or (warns and not quiet)) else "") + summary)

sys.exit(1 if (errors and not warn_only) else 0)
PY
