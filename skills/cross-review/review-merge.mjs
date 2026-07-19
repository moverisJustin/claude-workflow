#!/usr/bin/env node
// review-merge.mjs — mechanical merge of per-backend findings files.
//
// Part of `/cross-review pr`: each foreign backend emits a findings JSON
// conforming to schemas/findings.schema.json; this script merges them into
// one deduplicated, deterministically ordered list for the semantic pass.
//
// Usage:
//   node review-merge.mjs <backend>:<path> [<backend>:<path> ...]
//
// Each argument is BACKEND-TAGGED: the backend name, a colon, then the path
// to that backend's findings JSON (e.g. `codex:/tmp/rv/codex.json
// kimi:/tmp/rv/kimi.json`). The tag becomes the entry in each merged
// finding's `sources` array. Paths may contain further colons; only the
// FIRST colon splits.
//
// Dedup key: same `category` + same `file` + `line` within ±3 (two findings
// that both lack a line but share a file+category also merge; findings with
// no file never merge — the key is too weak). Merged finding keeps the first
// backend's fields as base, upgrades `severity` to the most severe across
// duplicates, unions `lessons` by pattern, and gains:
//   sources    — array of backend names that raised it
//   agreement  — true when 2+ DISTINCT backends raised it (high signal)
//
// Output (stdout): {"findings":[...], "coverage_notes":[{"backend":..,
// "coverage_notes":..}]} — findings ordered severity rank (critical, high,
// medium, low), then file (missing file last), then line, then summary.
// Deterministic for a given input set.
//
// Fail LOUD: unreadable file, malformed JSON, missing `findings` array, or a
// finding without its required fields → message on stderr, exit 1, no stdout
// output. Never skip a bad input silently, never emit a partial merge.
//
// Zero dependencies; system node.

import { readFileSync } from "node:fs";

const SEVERITY_RANK = { critical: 0, high: 1, medium: 2, low: 3 };
const LINE_TOLERANCE = 3;

function die(msg) {
  process.stderr.write(`review-merge: ${msg}\n`);
  process.exit(1);
}

const args = process.argv.slice(2);
if (args.length === 0) {
  die("usage: review-merge.mjs <backend>:<path> [<backend>:<path> ...]");
}

// --- parse and load inputs (fail loud on anything malformed) ---------------
const inputs = [];
for (const arg of args) {
  const sep = arg.indexOf(":");
  if (sep <= 0 || sep === arg.length - 1) {
    die(`bad argument "${arg}" — expected <backend>:<path>`);
  }
  const backend = arg.slice(0, sep);
  const path = arg.slice(sep + 1);

  let raw;
  try {
    raw = readFileSync(path, "utf8");
  } catch (err) {
    die(`cannot read ${path} (backend "${backend}"): ${err.message}`);
  }

  let doc;
  try {
    doc = JSON.parse(raw);
  } catch (err) {
    die(`malformed JSON in ${path} (backend "${backend}"): ${err.message}`);
  }

  if (
    typeof doc !== "object" ||
    doc === null ||
    Array.isArray(doc) ||
    !Array.isArray(doc.findings)
  ) {
    die(
      `${path} (backend "${backend}"): expected an object with a "findings" array`,
    );
  }

  doc.findings.forEach((f, i) => {
    if (typeof f !== "object" || f === null || Array.isArray(f)) {
      die(`${path} (backend "${backend}"): findings[${i}] is not an object`);
    }
    for (const field of ["severity", "category", "summary", "failure_scenario"]) {
      if (typeof f[field] !== "string" || f[field] === "") {
        die(
          `${path} (backend "${backend}"): findings[${i}] missing required "${field}"`,
        );
      }
    }
    if (!(f.severity in SEVERITY_RANK)) {
      die(
        `${path} (backend "${backend}"): findings[${i}] has unknown severity "${f.severity}"`,
      );
    }
    if (f.line !== undefined && !Number.isInteger(f.line)) {
      die(
        `${path} (backend "${backend}"): findings[${i}] "line" must be an integer`,
      );
    }
  });

  inputs.push({ backend, path, doc });
}

// --- merge ------------------------------------------------------------------
function normFile(f) {
  return typeof f.file === "string" && f.file !== "" ? f.file : null;
}
function normLine(f) {
  return Number.isInteger(f.line) ? f.line : null;
}

function isDuplicate(merged, candidate) {
  if (merged.category !== candidate.category) return false;
  const mf = normFile(merged);
  const cf = normFile(candidate);
  if (mf === null || cf === null) return false; // no file → key too weak to merge
  if (mf !== cf) return false;
  const ml = normLine(merged);
  const cl = normLine(candidate);
  if (ml === null && cl === null) return true; // same file+category, both lineless
  if (ml === null || cl === null) return false;
  return Math.abs(ml - cl) <= LINE_TOLERANCE;
}

const merged = [];
for (const { backend, doc } of inputs) {
  for (const finding of doc.findings) {
    const target = merged.find((m) => isDuplicate(m, finding));
    if (target) {
      if (!target.sources.includes(backend)) target.sources.push(backend);
      // most severe wins
      if (SEVERITY_RANK[finding.severity] < SEVERITY_RANK[target.severity]) {
        target.severity = finding.severity;
      }
      // union lessons by pattern
      if (Array.isArray(finding.lessons)) {
        const existing = new Set(
          (target.lessons || []).map((l) => l && l.pattern),
        );
        for (const lesson of finding.lessons) {
          if (lesson && !existing.has(lesson.pattern)) {
            target.lessons = target.lessons || [];
            target.lessons.push(lesson);
            existing.add(lesson.pattern);
          }
        }
      }
    } else {
      merged.push({ ...finding, sources: [backend] });
    }
  }
}

for (const m of merged) {
  m.agreement = m.sources.length >= 2;
}

// --- deterministic ordering: severity rank, then file, then line, summary ---
merged.sort((a, b) => {
  const sev = SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity];
  if (sev !== 0) return sev;
  const fa = normFile(a) ?? "￿"; // missing file sorts last
  const fb = normFile(b) ?? "￿";
  if (fa < fb) return -1;
  if (fa > fb) return 1;
  const la = normLine(a) ?? Number.MAX_SAFE_INTEGER;
  const lb = normLine(b) ?? Number.MAX_SAFE_INTEGER;
  if (la !== lb) return la - lb;
  return a.summary < b.summary ? -1 : a.summary > b.summary ? 1 : 0;
});

// --- coverage notes pass through, backend-tagged ----------------------------
const coverage = inputs
  .filter(
    (i) =>
      typeof i.doc.coverage_notes === "string" &&
      i.doc.coverage_notes.trim() !== "",
  )
  .map((i) => ({ backend: i.backend, coverage_notes: i.doc.coverage_notes }));

process.stdout.write(
  JSON.stringify({ findings: merged, coverage_notes: coverage }, null, 2) + "\n",
);
