#!/usr/bin/env bash
# bspec-validate.sh — offline conformance check for BSpec documents.
#
# The released BSpec CLI (v1.1.2) has NO offline `validate`: `pack`/`open`
# archive and read whatever you give them (a doc with type NOTAREALTYPE and no
# required fields packs clean). Its only analysis path is `bspec chat /analyze`,
# which needs an external OpenRouter/OpenAI key and a non-Claude LLM. So this is
# our own deterministic, offline, zero-API-key validator — the enforcement layer
# behind the bspec-doc skill and any CI gate.
#
# Usage:
#   bspec-validate.sh <file-or-dir> [more...]   validate a doc, or every *.md in a dir
#   bspec-validate.sh --quiet <target>          only print errors + summary
# Exit: 0 if no errors (warnings are non-fatal), 1 if any error, 2 on bad usage.
#
# Checks: YAML frontmatter present; required fields (id,title,type,status,
# version); type in the canonical BSpec catalog; status in the allowed set;
# relationship links (related/depends_on/enables/conflicts_with) resolve to a
# real doc id in the same corpus. owner/domain/created/updated + id/filename
# conventions are warnings, not errors.

set -euo pipefail

exec python3 - "$@" <<'PY'
import sys, os, re, glob

# Canonical BSpec type catalog: the standard's ~112 codes (bspec.dev/spec/v1-0-0)
# UNION the binary's compact set (CTX/OFF/PRF) so docs authored either way pass.
VALID_TYPES = set("""
VSN STR MSN VAL OBJ PUR THY MOT
MKT SEG CMP ECO TRN REG OPP POS THR
CUS PER USE STO PAI FEE CJM SUR JTB
PRD FEA SVC REQ QUA UXD ROD INT SUP
REV PRI CST VST CHN KPT KRS KAC
OPS PRO WFL ORG TEA ROL POL VND SKI
SYS API DAT ARC DEV INF SEC ANA
FIN BUD FOR FND INV VLU MET REP TAX AUD
RSK GOV COM INS INC CTL LEG ETH
INN EXP RND FUT LEA ADT IGN
DEC KNO LRN HYP RET WIS
BRD MSG CNT CAM SOC SEO MCH BPO IFL
CTX OFF PRF
""".split())

VALID_STATUS = {"Draft", "Review", "Accepted", "Deprecated"}
REQUIRED    = ["id", "title", "type", "status", "version"]
RECOMMENDED = ["owner", "domain", "created", "updated"]
REL_KEYS    = ["related", "depends_on", "enables", "conflicts_with"]

args = sys.argv[1:]
quiet = False
targets = []
for a in args:
    if a in ("--quiet", "-q"):
        quiet = True
    else:
        targets.append(a)

if not targets:
    sys.stderr.write("usage: bspec-validate.sh [--quiet] <file-or-dir> [...]\n")
    sys.exit(2)

def md_files(path):
    if os.path.isdir(path):
        return sorted(glob.glob(os.path.join(path, "**", "*.md"), recursive=True))
    return [path]

# Files to validate, and the corpus dirs whose ids relationships may reference.
files, corpus_dirs = [], set()
for t in targets:
    fs = md_files(t)
    files.extend(fs)
    if os.path.isdir(t):
        corpus_dirs.add(t)
    for f in fs:
        corpus_dirs.add(os.path.dirname(f) or ".")
# de-dupe files, preserve order
seen = set(); files = [f for f in files if not (f in seen or seen.add(f))]

def parse_frontmatter(text):
    """Minimal YAML-frontmatter parser (stdlib only — no pyyaml dependency).
    Handles `key: scalar`, block lists (`key:` then `  - item`), and flow lists
    (`key: [a, b]`). Returns dict {key: str|list} or None if no frontmatter."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    body = []
    i = 1
    while i < len(lines) and lines[i].strip() != "---":
        body.append(lines[i]); i += 1
    if i >= len(lines):          # never closed
        return None
    data, cur = {}, None
    for ln in body:
        mitem = re.match(r'^\s*-\s+(.*)$', ln)
        if mitem and cur is not None:
            data.setdefault(cur, [])
            if isinstance(data[cur], list):
                data[cur].append(mitem.group(1).strip().strip('"\''))
            continue
        m = re.match(r'^([A-Za-z0-9_]+):\s*(.*)$', ln)
        if not m:
            continue
        k, v = m.group(1), m.group(2).strip()
        cur = k
        if v == "":
            data[k] = []          # a block list may follow; else empty
        elif v.startswith("[") and v.endswith("]"):
            inner = v[1:-1].strip()
            data[k] = [x.strip().strip('"\'') for x in inner.split(",")] if inner else []
        else:
            data[k] = v.strip('"\'')
    return data

def as_list(v):
    if v is None: return []
    return v if isinstance(v, list) else [v]

# Pass 1: build the id set across the corpus for relationship checks.
id_set = set()
for d in corpus_dirs:
    for f in glob.glob(os.path.join(d, "**", "*.md"), recursive=True):
        try:
            fm = parse_frontmatter(open(f, encoding="utf-8").read())
        except Exception:
            fm = None
        if fm and isinstance(fm.get("id"), str) and fm["id"]:
            id_set.add(fm["id"])

# Pass 2: validate each target.
total_err = total_warn = 0
skipped = 0
for path in files:
    base = os.path.basename(path)
    if base == "README.md":
        continue
    try:
        text = open(path, encoding="utf-8").read()
    except Exception as e:
        print(f"FILE: {path}\n  ERROR: cannot read ({e})")
        total_err += 1; continue
    fm = parse_frontmatter(text)

    errors, warns = [], []
    if fm is None:
        # A file named directly must be a real doc; a stray note found while
        # scanning a directory is skipped rather than failed.
        if path in targets and not os.path.isdir(path):
            errors.append("missing or malformed YAML frontmatter")
        else:
            skipped += 1
            continue
    else:
        for r in REQUIRED:
            val = fm.get(r)
            if not val or (isinstance(val, list) and not val):
                errors.append(f"missing required field: {r}")
        t = fm.get("type")
        if isinstance(t, str) and t and t not in VALID_TYPES:
            errors.append(f"unknown type code '{t}' — not in the BSpec catalog")
        s = fm.get("status")
        if isinstance(s, str) and s and s not in VALID_STATUS:
            errors.append(f"invalid status '{s}' — must be Draft|Review|Accepted|Deprecated")
        i_ = fm.get("id")
        if isinstance(i_, str) and i_ and not re.match(r'^[A-Za-z0-9][A-Za-z0-9._-]*$', i_):
            warns.append(f"id '{i_}' has spaces/odd chars — prefer kebab-case (e.g. prd-checkout-001)")
        for r in RECOMMENDED:
            if not fm.get(r):
                warns.append(f"missing recommended field: {r}")
        if isinstance(t, str) and t and not base.upper().startswith(t.upper() + "-"):
            warns.append(f"filename should start with '{t}-' (convention: {t}-<name>-v<version>.md)")
        for key in REL_KEYS:
            for ref in as_list(fm.get(key)):
                if ref and id_set and ref not in id_set:
                    errors.append(f"{key} references unknown id '{ref}' (no doc with that id in the corpus)")

    total_err += len(errors); total_warn += len(warns)
    if errors or (warns and not quiet):
        print(f"FILE: {path}")
        for e in errors: print(f"  ERROR: {e}")
        if not quiet:
            for w in warns: print(f"  WARN:  {w}")
    elif not quiet:
        print(f"OK:   {path}")

checked = len(files) - skipped
print(f"\n{checked} document(s) checked, {total_err} error(s), {total_warn} warning(s)"
      + (f", {skipped} skipped (no frontmatter)" if skipped else ""))
sys.exit(1 if total_err else 0)
PY
