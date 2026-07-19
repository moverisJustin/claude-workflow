#!/usr/bin/env node
// validate-findings.mjs — zero-dependency JSON Schema validator for the
// RESTRICTED dialect used by the foreign-review findings schemas.
//
// jq is not a schema validator [ext-review codex:MMO-002]; this is. We own
// every schema this validates (plan-findings, cross-review findings), so the
// dialect is closed by construction:
//
//   type: object | array | string | integer
//   required, properties, additionalProperties:false
//   enum, maxItems, maxLength, items
//
// Fail-loud philosophy: a schema that uses ANY keyword outside the dialect is
// rejected (exit 1) rather than the keyword being silently ignored — a
// validator that skips a constraint it does not understand is worse than none.
// Annotation-only keys ($schema, title, description, default, examples) are
// permitted and ignored.
//
// Usage: node validate-findings.mjs <schema.json> <doc.json>
// Exit:  0 document valid / 1 anything else (usage, unreadable or unparsable
//        files, unsupported schema keyword, validation errors). Every error is
//        printed to stderr as "<path>: <reason>".

import { readFileSync } from "node:fs";

const ANNOTATIONS = new Set(["$schema", "title", "description", "default", "examples"]);
const KEYWORDS = new Set([
  "type", "required", "properties", "additionalProperties",
  "enum", "maxItems", "maxLength", "items",
]);
const TYPES = new Set(["object", "array", "string", "integer"]);

const errors = [];
function err(path, reason) { errors.push(`${path}: ${reason}`); }

function typeName(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  return typeof v; // object | string | number | boolean
}

// --- schema lint: enforce the closed dialect --------------------------------
function lintSchema(schema, path) {
  if (schema === null || typeof schema !== "object" || Array.isArray(schema)) {
    err(path, "schema node must be an object");
    return;
  }
  for (const key of Object.keys(schema)) {
    if (ANNOTATIONS.has(key)) continue;
    if (!KEYWORDS.has(key)) {
      err(path, `unsupported schema keyword '${key}' — restricted dialect allows only: ${[...KEYWORDS].join(", ")}`);
    }
  }
  if ("type" in schema && !TYPES.has(schema.type)) {
    err(path, `unsupported type '${schema.type}' — allowed: ${[...TYPES].join(", ")}`);
  }
  if ("required" in schema && (!Array.isArray(schema.required) || schema.required.some((r) => typeof r !== "string"))) {
    err(path, "'required' must be an array of strings");
  }
  if ("enum" in schema && (!Array.isArray(schema.enum) || schema.enum.length === 0)) {
    err(path, "'enum' must be a non-empty array");
  }
  if ("maxItems" in schema && !Number.isInteger(schema.maxItems)) {
    err(path, "'maxItems' must be an integer");
  }
  if ("maxLength" in schema && !Number.isInteger(schema.maxLength)) {
    err(path, "'maxLength' must be an integer");
  }
  if ("additionalProperties" in schema && schema.additionalProperties !== false) {
    err(path, "'additionalProperties' must be false (the dialect has no open-object or sub-schema form)");
  }
  if ("properties" in schema) {
    if (schema.properties === null || typeof schema.properties !== "object" || Array.isArray(schema.properties)) {
      err(path, "'properties' must be an object");
    } else {
      for (const [k, sub] of Object.entries(schema.properties)) {
        lintSchema(sub, `${path}.properties.${k}`);
      }
    }
  }
  if ("items" in schema) lintSchema(schema.items, `${path}.items`);
}

// --- document validation ----------------------------------------------------
function validate(value, schema, path) {
  if ("enum" in schema && Array.isArray(schema.enum)) {
    const hit = schema.enum.some((e) => JSON.stringify(e) === JSON.stringify(value));
    if (!hit) {
      err(path, `value ${JSON.stringify(value)} is not one of enum [${schema.enum.map((e) => JSON.stringify(e)).join(", ")}]`);
    }
  }

  if (!("type" in schema)) return;

  switch (schema.type) {
    case "object": {
      if (value === null || typeof value !== "object" || Array.isArray(value)) {
        err(path, `expected object, got ${typeName(value)}`);
        return;
      }
      // Object.hasOwn, never `in`: `in` walks the prototype chain, so extra
      // properties named "toString"/"constructor" would silently pass.
      if (Array.isArray(schema.required)) {
        for (const req of schema.required) {
          if (!Object.hasOwn(value, req)) err(path, `missing required property '${req}'`);
        }
      }
      const props = schema.properties && typeof schema.properties === "object" ? schema.properties : {};
      if (schema.additionalProperties === false) {
        for (const k of Object.keys(value)) {
          if (!Object.hasOwn(props, k)) err(path, `unexpected additional property '${k}'`);
        }
      }
      for (const [k, sub] of Object.entries(props)) {
        if (Object.hasOwn(value, k)) validate(value[k], sub, `${path}.${k}`);
      }
      break;
    }
    case "array": {
      if (!Array.isArray(value)) {
        err(path, `expected array, got ${typeName(value)}`);
        return;
      }
      if (Number.isInteger(schema.maxItems) && value.length > schema.maxItems) {
        err(path, `array has ${value.length} items, exceeds maxItems ${schema.maxItems}`);
      }
      if (schema.items && typeof schema.items === "object") {
        value.forEach((item, i) => validate(item, schema.items, `${path}[${i}]`));
      }
      break;
    }
    case "string": {
      if (typeof value !== "string") {
        err(path, `expected string, got ${typeName(value)}`);
        return;
      }
      if (Number.isInteger(schema.maxLength) && value.length > schema.maxLength) {
        err(path, `string length ${value.length} exceeds maxLength ${schema.maxLength}`);
      }
      break;
    }
    case "integer": {
      if (typeof value !== "number" || !Number.isInteger(value)) {
        err(path, `expected integer, got ${typeName(value)}${typeof value === "number" ? ` (${value})` : ""}`);
      }
      break;
    }
    default:
      // Unsupported types are reported by lintSchema; nothing more to do here.
      break;
  }
}

// --- main -------------------------------------------------------------------
function fail(msg) {
  process.stderr.write(`validate-findings: ${msg}\n`);
  process.exit(1);
}

const [schemaPath, docPath] = process.argv.slice(2);
if (!schemaPath || !docPath || process.argv.length > 4) {
  fail("usage: validate-findings.mjs <schema.json> <doc.json>");
}

function loadJson(path, label) {
  let raw;
  try {
    raw = readFileSync(path, "utf8");
  } catch (e) {
    fail(`cannot read ${label} ${path}: ${e.message}`);
  }
  try {
    return JSON.parse(raw);
  } catch (e) {
    fail(`${label} ${path} is not valid JSON: ${e.message}`);
  }
}

const schema = loadJson(schemaPath, "schema");
const doc = loadJson(docPath, "document");

lintSchema(schema, "$");
if (errors.length > 0) {
  for (const e of errors) process.stderr.write(`validate-findings: ${e}\n`);
  process.stderr.write(`validate-findings: schema rejected (${errors.length} problem${errors.length === 1 ? "" : "s"})\n`);
  process.exit(1);
}

validate(doc, schema, "$");
if (errors.length > 0) {
  for (const e of errors) process.stderr.write(`validate-findings: ${e}\n`);
  process.stderr.write(`validate-findings: INVALID — ${errors.length} error${errors.length === 1 ? "" : "s"}\n`);
  process.exit(1);
}
process.exit(0);
