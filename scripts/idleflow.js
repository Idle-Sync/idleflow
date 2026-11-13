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
//   gate   <limit> <slack> <numstat-all-file> <numstat-code-file> [uncommitted-paths-file]
//   guard                                   hook: payload on stdin; exit 2 blocks
//   killguard                               hook on Bash: payload on stdin; exit 2 blocks a kill by name or pattern
//   detach <cwd> <log> <pidfile> <command>  runs the command in its own session, output to log; writes its pid
//   entries <file> <key>                    one "name<TAB>value" line per entry of the object at that top-level key
//   unowned <file> <task-id>                NUL-separated paths on stdin; prints those the task may not change
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
// Counters may have been written as strings by hand: accept 3, "3", "2.5";
// reject lists, objects, "abc", "Infinity" (identical rules in idleflow.py).
function bad(v) {
  process.stderr.write(`idleflow: not a number: ${JSON.stringify(v)}\n`);
  process.exit(1);
}
function toNumber(v) {
  if (v === undefined || v === null || v === "") return 0;
  if (typeof v === "boolean" || (typeof v !== "number" && typeof v !== "string")) bad(v);
  // plain decimal only: no hex, no underscores, no "Infinity"; same regex in idleflow.py
  if (typeof v === "string" && !/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(v.trim())) bad(v);
  const n = Number(v);
  if (!Number.isFinite(n)) bad(v);
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

// `git diff -z --numstat`: "added<TAB>deleted<TAB>path<NUL>", or, for a rename, an empty path
// followed by "old<NUL>new<NUL>". NUL-separated paths are never quoted, so any name arrives as is.
function parseNumstat(text) {
  const toks = text.split("\0");
  const rows = [];
  for (let i = 0; i < toks.length; ) {
    const t = toks[i++];
    const tab1 = t.indexOf("\t");
    const tab2 = tab1 < 0 ? -1 : t.indexOf("\t", tab1 + 1);
    if (tab2 < 0) continue;
    let p = t.slice(tab2 + 1);
    if (p === "" && i + 1 < toks.length) { p = toks[i + 1]; i += 2; }
    const a = t.slice(0, tab1) === "-" ? 0 : parseInt(t.slice(0, tab1), 10); // binary files
    const d = t.slice(tab1 + 1, tab2) === "-" ? 0 : parseInt(t.slice(tab1 + 1, tab2), 10);
    rows.push([p, a, d]);
  }
  return rows;
}
function cmdGate(limit, slack, allFile, codeFile, uncommittedFile) {
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
  const uncommitted = uncommittedFile
    ? fs.readFileSync(uncommittedFile, "utf8").split("\0").filter((r) => r.length > 3).map((r) => r.slice(3)) // "XY path<NUL>"
    : [];
  console.log(
    JSON.stringify({
      added, deleted, total, files: codeRows.length,
      limit, slack, verdict,
      excluded_total: excludedTotal, top,
      uncommitted: uncommitted.length, uncommitted_paths: uncommitted.slice(0, 8),
    })
  );
}

// --- guard ------------------------------------------------------------------

// Absolute, forward-slash path. On Windows also maps MSYS/Cygwin forms
// (/d/x, /cygdrive/d/x) to D:/x and lower-cases for comparison.
// Absolute, forward-slash path with symlinks resolved, so a path through a link (macOS /var
// is /private/var) compares equal to the one git reports. A file about to be created does
// not exist yet, so the nearest existing parent is resolved and the rest kept as given.
function realPath(p) {
  const tail = [];
  let cur = p;
  for (;;) {
    try {
      return path.join(fs.realpathSync(cur), ...tail);
    } catch {
      const parent = path.dirname(cur);
      if (parent === cur) return p;
      tail.unshift(path.basename(cur));
      cur = parent;
    }
  }
}
function norm(p) {
  if (!p) return "";
  if (WIN) {
    const m = /^\/cygdrive\/([A-Za-z])(\/.*)?$/.exec(p) || /^\/([A-Za-z])(\/.*)?$/.exec(p);
    if (m) p = m[1].toUpperCase() + ":" + (m[2] || "/");
  }
  p = realPath(path.resolve(p)).replace(/\\/g, "/");
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
    let cand = path.join(d, ".idleflow", "runs", "active", "ownership.json");
    if (isFile(cand)) return cand;
    const marker = path.join(d, ".idleflow-run", "repo");
    if (isFile(marker)) {
      try {
        cand = path.join(norm(fs.readFileSync(marker, "utf8").trim()), ".idleflow", "runs", "active", "ownership.json");
        if (isFile(cand)) return cand;
      } catch {}
    }
    const parent = path.dirname(d);
    if (parent === d) return null;
    d = parent;
  }
}
// Ownership globs: '*' and '?' are the only wildcards and both cross '/'. Everything else is
// literal, brackets included: routes such as src/pages/[slug].astro are named with them.
// Same in idleflow.py.
function globToRegex(g) {
  let re = "";
  for (const c of g) {
    if (c === "*") re += ".*";
    else if (c === "?") re += ".";
    else re += c.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
  }
  return new RegExp("^" + re + "$", "s");
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

  // The run's own state is never edited through the editing tools: the orchestrator goes
  // through run.sh, and a task that could rewrite ownership.json, run.json or a worktree
  // marker could grant itself globs, approve itself, or make this guard find no map.
  const name = path.basename(p);
  if (p.includes("/.idleflow/runs/") && ["ownership.json", "run.json", "gate.json"].includes(name)) {
    process.stderr.write(`[idleflow] BLOCKED: ${name} is run state; use scripts/run.sh (set, own, inc) instead.\n`);
    process.exit(2);
  }
  if (p.includes("/.idleflow-run/") && name !== "result.md") {
    process.stderr.write(`[idleflow] BLOCKED: ${name} is a worktree marker; only .idleflow-run/result.md may be written.\n`);
    process.exit(2);
  }

  for (const [tid, t] of Object.entries(omap.tasks || {})) {
    const wt = norm(t.worktree || "");
    if (!wt) continue;
    if (p === wt || p.startsWith(wt + "/")) {
      const rel = p === wt ? "" : p.slice(wt.length + 1);
      const owns = Array.isArray(t.owns) ? t.owns : [];
      const shared = Array.isArray(omap.shared) ? omap.shared : [];
      if (globMatch(rel, owns.concat([".idleflow-run/result.md"], shared))) process.exit(0);
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
          `.idleflow/runs/**, .idleflow/lessons.md and suggestions.md, docs/**, root *.md and .gitignore during the build.\n`
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
  return (
    rel.startsWith(".idleflow/runs/") ||
    [".idleflow/lessons.md", ".idleflow/suggestions.md"].includes(rel) ||
    rel.startsWith("docs/") || rel === ".gitignore" || (!rel.includes("/") && rel.endsWith(".md"))
  );
}

// A new session: a caller that exits (a command substitution, a hook) must not take the server with it.
function cmdDetach(cwd, log, pidfile, command) {
  const { spawn } = require("child_process");
  const out = fs.openSync(log, "w");
  const proc = spawn("bash", ["-c", command], { cwd, detached: true, stdio: ["ignore", out, out] });
  proc.unref();
  fs.writeFileSync(pidfile, String(proc.pid));
}
function cmdEntries(file, key) {
  let obj;
  try {
    obj = load(file);
  } catch {
    return;
  }
  const section = isObj(obj) ? obj[key] : undefined;
  if (!isObj(section)) return;
  for (const [name, value] of Object.entries(section)) {
    const text = typeof value === "string" ? value : JSON.stringify(value);
    process.stdout.write(`${name}\t${text.replace(/[\t\n]/g, " ")}\n`);
  }
}
// The reviewers' ownership check, with the guard's matcher, so the two can never disagree.
function cmdUnowned(p, tid) {
  const omap = load(p);
  const task = (omap.tasks || {})[tid];
  if (!task) {
    process.stderr.write(`idleflow.js: task ${tid} is not in ${p}\n`);
    process.exit(1);
  }
  const owns = Array.isArray(task.owns) ? task.owns : [];
  const shared = Array.isArray(omap.shared) ? omap.shared : [];
  const allowed = owns.concat([".idleflow-run/**"], shared);
  // paths come NUL-separated (`git diff -z --name-only`), so none is quoted. git separates folders
  // with `/` on every OS; a `\` is part of a name and is kept, or `src\x.py` would pass as `src/x.py`.
  for (const rel of fs.readFileSync(0, "utf8").split("\0")) {
    if (rel && !globMatch(WIN ? rel.toLowerCase() : rel, allowed)) process.stdout.write(rel + "\n");
  }
}
// --- kill guard ---------------------------------------------------------------
// A kill by name or pattern matches every process on the machine with that text, other Claude Code
// sessions' included, so only a kill by a PID the agent kept is allowed. The command is read the way
// a shell reads it: quoted text is data, and $(...), backticks and `bash -c '...'` hold commands.
// Same in idleflow.py; the two must agree on every input.
const SHELLS = ["bash", "sh", "zsh", "dash", "ksh"];
const KEYWORDS = ["then", "do", "else", "elif", "if", "while", "until", "!", "{", "}", "time"];
// wrappers that run the rest of the line as a command, and their options that take a value
const WRAPPERS = {
  sudo: "ugChpUrtTD", doas: "uC", exec: "a", command: "", builtin: "", nohup: "",
  env: "uSCP", nice: "n", ionice: "cnp", timeout: "sk", watch: "nd", stdbuf: "ioe",
  setsid: "", xargs: "IinPLdsaE",
};
const NAME_KILLERS = ["pkill", "killall", "killall5", "skill"];
const PID_FINDERS = ["pgrep", "pidof"];
const baseName = (w) => w.slice(w.lastIndexOf("/") + 1);

// index just past the match of the opener at s[i] ("$(" or "`"), quotes and nesting respected
function closeAt(s, i, opener) {
  if (opener === "`") {
    let j = i + 1;
    while (j < s.length && s[j] !== "`") j += s[j] === "\\" ? 2 : 1;
    return j + 1;
  }
  let depth = 1, j = i + 2;
  while (j < s.length && depth) {
    const c = s[j];
    if (c === "\\") { j += 2; continue; }
    if (c === "'") { const k = s.indexOf("'", j + 1); j = k < 0 ? s.length : k + 1; continue; }
    if (c === '"') {
      j += 1;
      while (j < s.length && s[j] !== '"') j += s[j] === "\\" ? 2 : 1;
      j += 1;
      continue;
    }
    if (s.startsWith("$(", j)) { depth += 1; j += 2; continue; }
    if (c === ")") depth -= 1;
    j += 1;
  }
  return j;
}

// [[ [word, fromSubstitution], ... ], ...]: every simple command in s, nested ones too
function shellCommands(s, depth = 0) {
  const cmds = [];
  let words = [], word = "", subst = false, inWord = false;
  if (depth > 8) return cmds;
  const endWord = () => { if (inWord) words.push([word, subst]); word = ""; subst = false; inWord = false; };
  const endCmd = () => { endWord(); if (words.length) cmds.push(words); words = []; };
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    if (c === " " || c === "\t") endWord();
    else if ("\n;&|()".includes(c)) endCmd();
    else if (c === "#" && !inWord) { const k = s.indexOf("\n", i); i = k < 0 ? s.length : k; continue; }
    else if (c === "\\") {
      if (s.slice(i + 1, i + 2) === "\n") { i += 2; continue; }
      word += s.slice(i + 1, i + 2); inWord = true; i += 2; continue;
    } else if (c === "'") {
      let k = s.indexOf("'", i + 1); if (k < 0) k = s.length;
      word += s.slice(i + 1, k); inWord = true; i = k + 1; continue;
    } else if (c === '"') {
      let j = i + 1;
      while (j < s.length && s[j] !== '"') {
        if (s[j] === "\\") { word += s.slice(j + 1, j + 2); j += 2; }
        else if (s.startsWith("$(", j) || s[j] === "`") {
          const k = closeAt(s, j, s[j] === "$" ? "$(" : "`");
          const inner = s[j] === "$" ? s.slice(j + 2, k - 1) : s.slice(j + 1, k - 1);
          cmds.push(...shellCommands(inner, depth + 1));
          word += s.slice(j, k); subst = true; j = k;
        } else { word += s[j]; j += 1; }
      }
      inWord = true; i = j + 1; continue;
    } else if (s.startsWith("$(", i) || c === "`") {
      const k = closeAt(s, i, c === "$" ? "$(" : "`");
      const inner = c === "$" ? s.slice(i + 2, k - 1) : s.slice(i + 1, k - 1);
      cmds.push(...shellCommands(inner, depth + 1));
      word += s.slice(i, k); subst = true; inWord = true; i = k; continue;
    } else { word += c; inWord = true; }
    i += 1;
  }
  endCmd();
  // `bash -c '<script>'` runs its script as commands
  for (const ws of [...cmds]) {
    const names = ws.map((w) => w[0]);
    const k = names.indexOf("-c");
    if (SHELLS.includes(baseName(names[0])) && k >= 0 && k + 1 < names.length) cmds.push(...shellCommands(names[k + 1], depth + 1));
  }
  return cmds;
}

// [program name, its words, whether xargs runs it] after keywords, assignments and wrappers
function programOf(words) {
  let viaXargs = false, i = 0;
  while (i < words.length) {
    const w = words[i][0];
    if (KEYWORDS.includes(w) || /^[A-Za-z_][A-Za-z0-9_]*=/.test(w)) { i += 1; continue; }
    const name = baseName(w);
    if (!(name in WRAPPERS)) return [name, words.slice(i), viaXargs];
    viaXargs = viaXargs || name === "xargs";
    const takes = WRAPPERS[name];
    i += 1;
    while (i < words.length && words[i][0].startsWith("-") && words[i][0] !== "-") {
      const flag = words[i][0];
      i += 1;
      if (flag.length === 2 && takes.includes(flag[1]) && i < words.length) i += 1;
    }
    if (name === "timeout" && i < words.length) i += 1; // the duration
  }
  return ["", [], viaXargs];
}

function killByPattern(command) {
  const progs = shellCommands(command).map(programOf);
  const findsPids = progs.some(([name, ws]) =>
    PID_FINDERS.includes(name) || (name === "lsof" && ws.slice(1).some(([w]) => w.startsWith("-") && w.includes("t"))));
  for (const [name, ws, viaXargs] of progs) {
    if (NAME_KILLERS.includes(name)) return true;
    if (name === "fuser" && ws.slice(1).some(([w]) => w.startsWith("-") && !w.startsWith("--") && w.includes("k"))) return true;
    if (name === "kill" && (viaXargs || findsPids || ws.slice(1).some(([, sub]) => sub))) return true;
  }
  return false;
}

function cmdKillguard() {
  let cmd;
  try {
    cmd = (JSON.parse(fs.readFileSync(0, "utf8")).tool_input || {}).command;
  } catch {
    process.exit(0);
  }
  if (typeof cmd === "string" && killByPattern(cmd)) {
    process.stderr.write(
      "[idleflow] BLOCKED: this ends processes by name or pattern, which also ends other " +
        "sessions' work on this machine. End only a process you started, by the PID you kept " +
        "(kill <pid>, or kill -- -<pid> for its group); give a command that may hang the Bash " +
        "tool's timeout instead of killing it afterwards.\n"
    );
    process.exit(2);
  }
  process.exit(0);
}
const table = { get: cmdGet, set: cmdSet, inc: cmdInc, finish: cmdFinish, own: cmdOwn, gate: cmdGate, guard: cmdGuard, killguard: cmdKillguard, detach: cmdDetach, entries: cmdEntries, unowned: cmdUnowned };
const [cmd, ...args] = process.argv.slice(2);
if (!cmd || !(cmd in table)) {
  process.stderr.write(`idleflow.js: unknown subcommand ${JSON.stringify(cmd)}\n`);
  process.exit(1);
}
table[cmd](...args);
