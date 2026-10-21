#!/usr/bin/env node
// idleflow helper (Node). scripts/idleflow.py is the same program in Python.
//
// Both are kept identical in behaviour; rt.sh runs whichever runtime exists.
// If you change a subcommand here, change it in idleflow.py too and run
// scripts/selftest.sh with IDLEFLOW_RUNTIME=python and =node.
//
// Subcommands:
//   get    <file> <dotted.key>              print the value (strings raw, else JSON)
//   set    <file> <dotted.key> <json>       set a value, creating parents
//   inc    <file> <dotted.key> [n]          add n (default 1) to a number
//   finish <file> <status> <log.jsonl>      stamp status+finished, append to log
//   own    <file> <task-id> <worktree> <globs-json>
//   gate   <limit> <slack> <numstat-all-file> <numstat-code-file>
//   guard                                   hook: payload on stdin; exit 2 blocks
"use strict";
const fs = require("fs");
const path = require("path");

const WIN = process.platform === "win32";

function load(p) {
  return JSON.parse(fs.readFileSync(p, "utf8"));
}
function save(p, obj) {
  fs.writeFileSync(p, JSON.stringify(obj, null, 1) + "\n");
}
function isObj(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}
function walk(obj, key, create) {
  let cur = obj;
  const parts = key.split(".");
  for (const k of parts.slice(0, -1)) {
    if (!isObj(cur[k])) {
      if (!create) return [null, null];
      cur[k] = {};
    }
    cur = cur[k];
  }
  return [cur, parts[parts.length - 1]];
}

function cmdGet(p, key) {
  const [cur, last] = walk(load(p), key, false);
  if (cur === null || !(last in cur)) process.exit(1);
  const v = cur[last];
  console.log(typeof v === "string" ? v : JSON.stringify(v));
}
function cmdSet(p, key, val) {
  const obj = load(p);
  const [cur, last] = walk(obj, key, true);
  cur[last] = JSON.parse(val);
  save(p, obj);
}
// Counters may have been written as strings by hand; accept "3", reject "abc".
function toNumber(v) {
  if (v === undefined || v === null || v === "") return 0;
  const n = Number(v);
  if (Number.isNaN(n)) {
    process.stderr.write(`idleflow: not a number: ${JSON.stringify(v)}\n`);
    process.exit(1);
  }
  return n;
}
function cmdInc(p, key, n = "1") {
  const obj = load(p);
  const [cur, last] = walk(obj, key, true);
  cur[last] = toNumber(cur[last]) + toNumber(n);
  save(p, obj);
  console.log(String(cur[last]));
}
function cmdFinish(p, status, log) {
  const r = load(p);
  r.status = status;
  r.finished = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  save(p, r);
  fs.appendFileSync(log, JSON.stringify(r) + "\n");
}
function cmdOwn(p, tid, wt, globs) {
  const o = load(p);
  if (!isObj(o.tasks)) o.tasks = {};
  o.tasks[tid] = { worktree: wt, owns: JSON.parse(globs) };
  save(p, o);
}

// --- gate -------------------------------------------------------------------

function parseNumstat(text) {
  const rows = [];
  for (const line of text.split(/\r?\n/)) {
    const parts = line.split("\t");
    if (parts.length < 3) continue;
    const a = parts[0] === "-" ? 0 : parseInt(parts[0], 10); // binary files
    const d = parts[1] === "-" ? 0 : parseInt(parts[1], 10);
    rows.push([parts[2], a, d]);
  }
  return rows;
}
function cmdGate(limit, slack, allFile, codeFile) {
  limit = parseInt(limit, 10);
  slack = parseInt(slack, 10);
  const allRows = parseNumstat(fs.readFileSync(allFile, "utf8"));
  const codeRows = parseNumstat(fs.readFileSync(codeFile, "utf8"));
  const added = codeRows.reduce((s, r) => s + r[1], 0);
  const deleted = codeRows.reduce((s, r) => s + r[2], 0);
  const total = added + deleted;
  const excludedTotal = allRows.reduce((s, r) => s + r[1] + r[2], 0) - total;
  const verdict = total <= limit ? "ok" : total <= limit + slack ? "audit" : "split";
  const top = codeRows
    .map((r) => [r[0], r[1] + r[2]])
    .sort((x, y) => y[1] - x[1])
    .slice(0, 8);
  console.log(
    JSON.stringify({
      added, deleted, total, files: codeRows.length,
      limit, slack, verdict,
      excluded_total: excludedTotal, top,
    })
  );
}

// --- guard ------------------------------------------------------------------

// Absolute, forward-slash path. On Windows also maps MSYS/Cygwin forms
// (/d/x, /cygdrive/d/x) to D:/x and lower-cases for comparison.
function norm(p) {
  if (!p) return "";
  if (WIN) {
    const m = /^\/cygdrive\/([A-Za-z])(\/.*)?$/.exec(p) || /^\/([A-Za-z])(\/.*)?$/.exec(p);
    if (m) p = m[1].toUpperCase() + ":" + (m[2] || "/");
  }
  p = path.resolve(p).replace(/\\/g, "/");
  return WIN ? p.toLowerCase() : p;
}
function isFile(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}
function findMap(start) {
  let d = norm(start);
  for (;;) {
    let cand = path.join(d, ".claude", "runs", "active", "ownership.json");
    if (isFile(cand)) return cand;
    const marker = path.join(d, ".claude-run", "repo");
    if (isFile(marker)) {
      try {
        cand = path.join(norm(fs.readFileSync(marker, "utf8").trim()), ".claude", "runs", "active", "ownership.json");
        if (isFile(cand)) return cand;
      } catch {}
    }
    const parent = path.dirname(d);
    if (parent === d) return null;
    d = parent;
  }
}
// fnmatch semantics: '*' and '?' also cross '/' (same as Python's fnmatch).
function globToRegex(g) {
  let re = "";
  for (let i = 0; i < g.length; i++) {
    const c = g[i];
    if (c === "*") re += ".*";
    else if (c === "?") re += ".";
    else if (c === "[") {
      const j = g.indexOf("]", i + 1);
      if (j === -1) re += "\\[";
      else {
        let cls = g.slice(i + 1, j);
        if (cls.startsWith("!")) cls = "^" + cls.slice(1);
        re += "[" + cls.replace(/\\/g, "\\\\") + "]";
        i = j;
      }
    } else re += c.replace(/[.+^${}()|\\\/]/g, "\\$&");
  }
  return new RegExp("^" + re + "$");
}
function globMatch(rel, globs) {
  for (let g of globs) {
    g = g.replace(/\\/g, "/");
    if (WIN) g = g.toLowerCase();
    if (globToRegex(g).test(rel)) return true;
    if (g.endsWith("/**")) {
      const base = g.slice(0, -3);
      if (rel === base || rel.startsWith(base + "/")) return true;
    }
  }
  return false;
}
function cmdGuard() {
  let payload;
  try {
    payload = JSON.parse(fs.readFileSync(0, "utf8"));
  } catch {
    process.exit(0);
  }
  const ti = payload.tool_input || {};
  const raw = ti.file_path || ti.notebook_path || "";
  if (!raw) process.exit(0);
  const p = norm(raw);
  const cwd = payload.cwd || process.cwd();

  const mp = findMap(path.dirname(p)) || findMap(cwd);
  if (mp === null) process.exit(0);
  let omap;
  try {
    omap = load(mp);
  } catch {
    process.exit(0);
  }
  for (const [tid, t] of Object.entries(omap.tasks || {})) {
    const wt = norm(t.worktree || "");
    if (!wt) continue;
    if (p === wt || p.startsWith(wt + "/")) {
      const rel = p === wt ? "" : p.slice(wt.length + 1);
      const owns = Array.isArray(t.owns) ? t.owns : [];
      if (globMatch(rel, owns.concat([".claude-run/**"]))) process.exit(0);
      process.stderr.write(
        `[idleflow] BLOCKED: ${rel} is not owned by task ${tid}.\n` +
          `Owned globs: ${JSON.stringify(owns)}\n` +
          `If this file must change, stop and report it in your task report under ` +
          `'blocked_on' so the orchestrator can reassign ownership. Do not work around this.\n`
      );
      process.exit(2);
    }
  }

  // Not in a worktree. While tasks are building, the main checkout is off limits for code:
  // an implementer that forgot to cd would otherwise write where no reviewer looks.
  const repo = norm(omap.repo || "");
  if (repo && (p === repo || p.startsWith(repo + "/")) && building(path.dirname(mp))) {
    const rel = p === repo ? "" : p.slice(repo.length + 1);
    if (!orchestratorFile(rel)) {
      process.stderr.write(
        `[idleflow] BLOCKED: ${rel} is in the main checkout while tasks are building.\n` +
          `Implementers edit only inside their worktree; the orchestrator edits only ` +
          `.claude/**, docs/**, root *.md and .gitignore during the build.\n`
      );
      process.exit(2);
    }
  }
  process.exit(0);
}
// True while any task in run.json has status "building".
function building(runDir) {
  let run;
  try {
    run = load(path.join(runDir, "run.json"));
  } catch {
    return false;
  }
  return Object.values(run.tasks || {}).some((t) => isObj(t) && t.status === "building");
}
// Paths the orchestrator may write in the main checkout mid-build.
function orchestratorFile(rel) {
  return rel.startsWith(".claude/") || rel.startsWith("docs/") || rel === ".gitignore" || (!rel.includes("/") && rel.endsWith(".md"));
}

const table = { get: cmdGet, set: cmdSet, inc: cmdInc, finish: cmdFinish, own: cmdOwn, gate: cmdGate, guard: cmdGuard };
const [cmd, ...args] = process.argv.slice(2);
if (!cmd || !(cmd in table)) {
  process.stderr.write(`idleflow.js: unknown subcommand ${JSON.stringify(cmd)}\n`);
  process.exit(1);
}
table[cmd](...args);
