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
//   clip   <n> <text>                       the text cut to at most n characters (not bytes), "..." marking a cut
//   unowned <file> <task-id>                NUL-separated paths on stdin; prints those the task may not change
//   outside <globs-json>                    NUL-separated paths on stdin; prints those no glob covers
//   port-free <port>                        exit 0 when nothing on this machine listens on the TCP port, else 1
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
function cmdOutside(globs) {
  // The plan check's matcher is the guard's, so a plan that passes is one the guard lets build.
  const allowed = JSON.parse(globs);
  for (const rel of fs.readFileSync(0, "utf8").split("\0")) {
    if (rel && !globMatch(WIN ? rel.toLowerCase() : rel, allowed)) process.stdout.write(rel + "\n");
  }
}
// --- kill guard ---------------------------------------------------------------
// A kill by name or pattern matches every process on the machine with that text, other Claude Code
// sessions' included, so only a kill of a PID the agent kept is allowed. The command is read the way
// a shell reads it: quoted text and here-document bodies are data; $(...), backticks, `bash -c`,
// `eval` and `watch` hold commands. Same in idleflow.py; the two must agree on every input.
const SHELLS = ["bash", "sh", "zsh", "dash", "ksh"];
// words that start a command without being its program
const KEYWORDS = ["then", "do", "else", "elif", "if", "while", "until", "!", "{", "}", "time", "coproc"];
// compound commands: a statement runs on to its closing word, so a whole loop is one statement
const OPENERS = ["if", "while", "until", "for", "select", "case"];
const CLOSERS = ["fi", "done", "esac"];
const HEADERS = ["for", "select", "case", "in", "esac"]; // their words are a list, not a command
// wrapper -> [short options that take a value, long options that take a value, words before the command]
const WRAPPERS = new Map(Object.entries({
  sudo: ["ugChpUrtTD", ["user", "group", "host", "prompt", "close-from", "role", "type"], 0],
  doas: ["uC", [], 0], exec: ["a", [], 0], command: ["", [], 0], builtin: ["", [], 0],
  nohup: ["", [], 0], env: ["uSCP", ["unset", "chdir", "split-string"], 0],
  nice: ["n", ["adjustment"], 0], ionice: ["cnp", ["class", "classdata", "pid"], 0],
  timeout: ["sk", ["signal", "kill-after"], 1], stdbuf: ["ioe", ["input", "output", "error"], 0],
  setsid: ["", [], 0],
  xargs: ["IinPLdsaE", ["replace", "max-args", "max-procs", "max-lines", "delimiter", "max-chars",
                        "arg-file", "eof"], 0],
  chrt: ["", [], 1], taskset: ["", [], 1], strace: ["eoOpPsSuUXba", [], 0], unbuffer: ["", [], 0],
  flock: ["Ew", ["conflict-exit-code", "wait", "timeout"], 1],
  runuser: ["ugGw", ["user", "group", "supp-group", "whitelist-environment"], 0],
  "systemd-run": ["upE", ["unit", "property", "setenv", "uid", "gid", "slice", "description"], 0],
  npx: ["p", ["package", "call"], 0], bunx: ["p", ["package"], 0], busybox: ["", [], 0],
}));
// programs that run the word after a -c option (or --command) as a shell script
const SCRIPT_OPTION = ["su", "runuser", "script", "flock"];
const NAME_KILLERS = ["pkill", "killall", "killall5", "skill", "kill-port", "fkill", "fkill-cli"];
const PID_LISTERS = ["pgrep", "pidof", "ps", "lsof", "fuser", "ss", "netstat"];
// a hook gets 10 s: refuse a command longer than MAX_INPUT, nested deeper than MAX_DEPTH, needing
// more than MAX_WORK characters lexed in all, or taking longer than MAX_MS to read
const MAX_INPUT = 100000, MAX_DEPTH = 12, MAX_WORK = 400000, MAX_MS = 4000;
const ASSIGN_RE = /^([A-Za-z_][A-Za-z0-9_]*)\+?=/;
class TooComplex extends Error {}
class Refuse extends Error {}
const baseName = (w) => w.slice(w.lastIndexOf("/") + 1);

// index just past the end of the "$(" or backtick that starts at s[i]; quotes and nesting respected
function closeAt(s, i) {
  if (s[i] === "`") {
    let j = i + 1;
    while (j < s.length && s[j] !== "`") j += s[j] === "\\" ? 2 : 1;
    return Math.min(j + 1, s.length);
  }
  let depth = 1, j = i + 2;
  while (j < s.length && depth) {
    const c = s[j];
    if (c === "\\") j += 2;
    else if (c === "'") { const k = s.indexOf("'", j + 1); j = k < 0 ? s.length : k + 1; }
    else if (c === '"') {
      j += 1;
      while (j < s.length && s[j] !== '"') j += s[j] === "\\" ? 2 : 1;
      j += 1;
    } else if (c === "(") { depth += 1; j += 1; }
    else { if (c === ")") depth -= 1; j += 1; }
  }
  return Math.min(j, s.length);
}

// [the script inside the "$(" or backtick at s[i], the index past its end]
function innerAt(s, i) {
  const k = closeAt(s, i);
  return [s[i] === "$" ? s.slice(i + 2, k - 1) : s.slice(i + 1, k - 1), k];
}

// index just past the "))" that closes the "((" at s[i], or 0 when the two do not close
// together; what it reads counts as work, since "((((..." would read the rest once per "("
function arithEnd(s, i, work) {
  let depth = 0, j = i, end = 0;
  for (; j < s.length; j++) {
    if (s[j] === "(") depth += 1;
    else if (s[j] === ")") {
      depth -= 1;
      if (depth === 1 && s[j + 1] !== ")") break;
      if (depth === 0) { end = j + 1; break; }
    }
  }
  work[0] += j - i;
  if (work[0] > MAX_WORK) throw new TooComplex();
  return end;
}

// the $(...) and backtick scripts in a piece of text that holds no other commands
function substitutions(text) {
  const subs = [];
  let k = 0;
  while (k < text.length) {
    if (text.startsWith("$(", k) || text[k] === "`") { const [inner, next] = innerAt(text, k); subs.push(inner); k = next; }
    else k += 1;
  }
  return subs;
}

// The commands of one script, nothing nested parsed yet; see _lex in idleflow.py.
function lex(s, work) {
  work[0] += s.length;
  if (work[0] > MAX_WORK || Date.now() > work[1]) throw new TooComplex();
  const cmds = [];
  let stmt = 0, compound = 0, pending = [];
  const st = { cmd: { words: [], subs: [], docs: [], stmt: 0 }, word: null, redirect: false };
  const w = () => { if (st.word === null) st.word = { text: "", subs: [] }; return st.word; };
  const endWord = () => {
    const word = st.word;
    if (word !== null) {
      if (st.redirect) { st.cmd.subs.push(...word.subs); st.redirect = false; } // a redirection target is not an argument
      else st.cmd.words.push(word);
    }
    st.word = null;
  };
  const endCmd = (boundary) => {
    endWord();
    const cmd = st.cmd;
    if (cmd.words.length || cmd.subs.length || cmd.docs.length) {
      const first = cmd.words.length ? cmd.words[0].text : "";
      cmd.stmt = stmt;
      cmds.push(cmd);
      compound = Math.max(0, compound + (OPENERS.includes(first) ? 1 : 0) - (CLOSERS.includes(first) ? 1 : 0));
    }
    if (boundary && compound === 0) stmt += 1;
    st.cmd = { words: [], subs: [], docs: [], stmt };
  };
  let i = 0, steps = 0;
  const n = s.length;
  while (i < n) {
    steps += 1;
    if (steps % 4096 === 0 && Date.now() > work[1]) throw new TooComplex();
    const c = s[i];
    const start = c === "$" ? i + 1 : i;
    let k = 0;
    if (s.startsWith("$((", i) || (s.startsWith("((", i) && st.word === null && !st.cmd.words.length)) k = arithEnd(s, start, work);
    if (k) {
      // arithmetic, which bash takes only when the "((" closes with "))"; see _lex in idleflow.py
      w().subs.push(s.slice(start + 2, k - 2));
      w().text += s.slice(i, k);
      i = k;
    } else if (c === " " || c === "\t") { endWord(); i += 1; }
    else if (c === "\n") {
      endCmd(true);
      i += 1;
      for (const [delim, quoted, strip, owner] of pending) {
        const body = [];
        while (i < n) {
          let k = s.indexOf("\n", i);
          if (k < 0) k = n;
          const line = s.slice(i, k);
          i = k + 1;
          if ((strip ? line.replace(/^\t+/, "") : line) === delim) break;
          body.push(line);
        }
        owner.docs.push([body.join("\n"), quoted]);
      }
      pending = [];
    } else if (c === "&" && s.slice(i + 1, i + 2) === ">") { endWord(); i += 2; st.redirect = true; }
    else if (";&|()".includes(c)) {
      const two = s.slice(i, i + 2);
      endCmd(c !== "|" || two === "||");
      i += ["&&", "||", ";;"].includes(two) ? 2 : 1;
    } else if ((c === "<" || c === ">") && s.slice(i + 1, i + 2) === "(") {
      const k = closeAt(s, i); // <(...) and >(...) run a command, like $(...)
      w().subs.push(s.slice(i + 2, k - 1));
      w().text += s.slice(i, k);
      i = k;
    } else if (c === "<" || c === ">") {
      const word = st.word;
      if (word !== null && /^[0-9]+$/.test(word.text) && !word.subs.length) st.word = null; // a file descriptor number, as in 2>&1
      endWord();
      if (s.startsWith("<<", i) && !s.startsWith("<<<", i)) {
        let j = i + 2;
        const strip = s.slice(j, j + 1) === "-";
        if (strip) j += 1;
        while (j < n && (s[j] === " " || s[j] === "\t")) j += 1;
        let k = j;
        while (k < n && !" \t\n;&|()<>".includes(s[k])) k += 1;
        const raw = s.slice(j, k);
        const quoted = /['"\\]/.test(raw);
        pending.push([raw.replace(/['"\\]/g, ""), quoted, strip, st.cmd]);
        i = k;
      } else {
        while (i < n && "<>&|".includes(s[i])) i += 1;
        st.redirect = true;
      }
    } else if (c === "#" && st.word === null) { const k = s.indexOf("\n", i); i = k < 0 ? n : k; }
    else if (c === "\\") { if (s.slice(i + 1, i + 2) !== "\n") w().text += s.slice(i + 1, i + 2); i += 2; }
    else if (c === "'" || (c === "$" && s.slice(i + 1, i + 2) === "'")) {
      const ansi = c === "$";
      let j = ansi ? i + 2 : i + 1;
      while (j < n && s[j] !== "'") {
        if (ansi && s[j] === "\\") {
          const e = s.slice(j + 1, j + 2);
          w().text += e === "n" ? "\n" : e === "t" ? "\t" : e;
          j += 2;
        } else { w().text += s[j]; j += 1; }
      }
      w();
      i = j + 1;
    } else if (c === '"' || (c === "$" && s.slice(i + 1, i + 2) === '"')) {
      let j = c === "$" ? i + 2 : i + 1;
      while (j < n && s[j] !== '"') {
        if (s[j] === "\\") { w().text += s.slice(j + 1, j + 2); j += 2; }
        else if (s.startsWith("$(", j) || s[j] === "`") {
          const [inner, k] = innerAt(s, j);
          w().subs.push(inner);
          w().text += s.slice(j, k);
          j = k;
        } else { w().text += s[j]; j += 1; }
      }
      w();
      i = j + 1;
    } else if (s.startsWith("$(", i) || c === "`") {
      const [inner, k] = innerAt(s, i);
      w().subs.push(inner);
      w().text += s.slice(i, k);
      i = k;
    } else { w().text += c; i += 1; }
  }
  endCmd(true);
  return cmds;
}

// index of the first word after the options that start at words[i]
function skipOptions(words, i, shortTakes, longTakes) {
  while (i < words.length) {
    const t = words[i].text;
    if (t === "--") return i + 1;
    if (!t.startsWith("-") || t === "-") return i;
    i += 1;
    if (t.startsWith("--")) { if (!t.includes("=") && longTakes.includes(t.slice(2))) i += 1; }
    else if (shortTakes.includes(t[t.length - 1])) i += 1; // the value of the cluster's last letter: -u root, -iu root
  }
  return i;
}

// index of the word after a short-option cluster holding "c" (-c, -lc, -qc) or after --command
function scriptAfterC(words) {
  for (let k = 0; k < words.length; k++) {
    const t = words[k].text;
    if (t === "--") return -1;
    if (t === "--command" || (t.startsWith("-") && !t.startsWith("--") && t.slice(1).includes("c"))) {
      return k + 1 < words.length ? k + 1 : -1;
    }
    if (!t.startsWith("-")) return -1;
  }
  return -1;
}

// [name, its words, whether xargs runs it, the indexes of `rest` that hold a script it runs]
function programOf(words) {
  let viaXargs = false, i = 0;
  while (i < words.length) {
    const t = words[i].text;
    if (KEYWORDS.includes(t) || ASSIGN_RE.test(t)) { i += 1; continue; }
    const name = baseName(t), rest = words.slice(i);
    if (SHELLS.includes(name) || SCRIPT_OPTION.includes(name)) {
      const k = scriptAfterC(rest.slice(1));
      if (k >= 0) return [name, rest, viaXargs, [1 + k]];
      if (SHELLS.includes(name)) return [name, rest, viaXargs, []];
    }
    if (name === "eval" || name === "watch") {
      const start = skipOptions(rest, 1, name === "watch" ? "nd" : "", ["interval", "differences"]);
      const at = [];
      for (let k = start; k < rest.length; k++) at.push(k);
      return [name, rest, viaXargs, at];
    }
    if (name === "command" && rest.length > 1 && (rest[1].text === "-v" || rest[1].text === "-V")) {
      return [name, rest, viaXargs, []]; // only names a program, runs nothing
    }
    if (name === "trap") {
      const k = skipOptions(rest, 1, "", []);
      return [name, rest, viaXargs, k < rest.length && rest[1].text !== "-p" && rest[1].text !== "-l" ? [k] : []];
    }
    if ((name === "pnpm" || name === "yarn") && rest.length > 1 && rest[1].text === "dlx") { i += 2; continue; }
    if (!WRAPPERS.has(name)) return [name, rest, viaXargs, []];
    let [shortTakes, longTakes, positional] = WRAPPERS.get(name);
    viaXargs = viaXargs || name === "xargs";
    const optionsEnd = skipOptions(words, i + 1, shortTakes, longTakes);
    const later = rest.slice(1).map((wd) => wd.text);
    if (name === "taskset" && later.some((t) => ["-c", "-p", "--cpu-list", "--pid"].includes(t))) {
      positional = later.some((t) => t === "-p" || t === "--pid") ? 0 : 1;
    }
    i = optionsEnd + positional;
  }
  return ["", [], viaXargs, []];
}

// PID -1 signals every process the user may signal
function killsAll(args) {
  let signal = false;
  for (let k = 0; k < args.length; k++) {
    const t = args[k].text;
    if (t === "--") return args.slice(k + 1).some((a) => a.text === "-1");
    if (t === "-1" && signal) return true;
    if (t.startsWith("-") && t !== "-l" && t !== "-L") signal = true;
  }
  return false;
}

const LISTER = "<lists pids>", DYNAMIC_KILL = "<kills a computed pid>";
const LITERAL_PID_RE = /^(--|-?[0-9]+|%[0-9]*|-[A-Za-z][A-Za-z0-9+-]*)$/;

// options of ps and lsof that only shape the output, and the ones that take a value
const PID_ONLY = {
  ps: [["-f", "-F", "-l", "-w", "-ww", "-H", "--no-headers", "--no-heading", "--forest"],
    ["-p", "-q", "--pid", "--quick-pid", "-o", "-O", "--format"]],
  lsof: [["-n", "-P", "-w", "-l", "-b", "-a", "-nP", "-Pn", "-V"], ["-p"]],
};

// ps -p <pid> / lsof -p <pid> with nothing else that selects processes; see _looks_up_given_pids
function looksUpGivenPids(name, args) {
  if (!Object.prototype.hasOwnProperty.call(PID_ONLY, name)) return false;
  const [flags, valued] = PID_ONLY[name];
  let selects = false, k = 0;
  while (k < args.length) {
    const t = args[k].text;
    let option, value;
    if (flags.includes(t)) { k += 1; continue; }
    if (valued.includes(t)) {
      if (k + 1 >= args.length) return false;
      option = t; value = args[k + 1].text; k += 2;
    } else {
      option = valued.find((v) => (v.startsWith("--") && t.startsWith(v + "=")) ||
        (!v.startsWith("--") && v.length === 2 && t.startsWith(v) && t.length > 2));
      if (option === undefined) return false;
      value = t.slice(option.length + (option.startsWith("--") ? 1 : 0)); k += 1;
    }
    if (["-p", "-q", "--pid", "--quick-pid"].includes(option)) {
      if (value.includes("^")) return false;
      selects = true;
    }
  }
  return selects;
}

function isLister(name, args) {
  return PID_LISTERS.includes(name) && !looksUpGivenPids(name, args);
}

// [refuse, what this script and everything nested in it runs: program names, plus LISTER when
// something finds PIDs, plus DYNAMIC_KILL when a kill's PID is not written out]
function scan(script, work, depth) {
  if (depth > MAX_DEPTH) throw new TooComplex();
  const seen = new Set();
  const nested = (sub) => {
    const [refuse, progs] = scan(sub, work, depth + 1);
    if (refuse) throw new Refuse();
    return progs;
  };
  const addAll = (set, items) => { for (const x of items) set.add(x); };
  try {
    for (const cmd of lex(script, work)) {
      const words = cmd.words;
      let name = "", rest = [], viaXargs = false, scriptAt = [];
      if (words.length && !HEADERS.includes(words[0].text)) [name, rest, viaXargs, scriptAt] = programOf(words);
      const args = rest.slice(1);
      const here = new Set(name ? [name] : []);
      const scriptWords = new Set(scriptAt.map((k) => rest[k]));
      if (scriptAt.length) addAll(here, nested(scriptAt.map((k) => rest[k].text).join(" ")));
      const argPrograms = new Map();
      for (const wd of words) {
        if (scriptWords.has(wd)) continue; // its substitutions are part of the script just read
        const progs = new Set();
        for (const sub of wd.subs) addAll(progs, nested(sub));
        argPrograms.set(wd, progs);
        addAll(here, progs);
      }
      for (const sub of cmd.subs) addAll(here, nested(sub));
      for (const [body, quoted] of cmd.docs) {
        if (SHELLS.includes(name) && !scriptAt.length) addAll(here, nested(body)); // bash <<EOF: the body is the script
        else if (!quoted) for (const sub of substitutions(body)) addAll(here, nested(sub));
      }
      if (NAME_KILLERS.includes(name)) return [true, seen];
      if (name === "fuser" && args.some((a) => a.text === "--kill" ||
          (a.text.startsWith("-") && !a.text.startsWith("--") && a.text.includes("k")))) return [true, seen];
      if (name === "find") {
        const texts = args.map((a) => a.text);
        for (let k = 0; k < texts.length; k++) {
          if (["-exec", "-execdir", "-ok", "-okdir"].includes(texts[k])) {
            let end = texts.length;
            for (let m = k + 1; m < texts.length; m++) if (texts[m] === ";" || texts[m] === "+") { end = m; break; }
            const [inner, innerRest, , innerAt] = programOf(args.slice(k + 1, end));
            if (NAME_KILLERS.includes(inner) || inner === "kill") return [true, seen];
            if (innerAt.length) addAll(here, nested(innerAt.map((m) => innerRest[m].text).join(" ")));
          }
        }
      }
      if (isLister(name, args)) here.add(LISTER);
      if (name === "kill") {
        if (killsAll(args) || args.some((a) => (argPrograms.get(a) || new Set()).has(LISTER))) return [true, seen];
        if (args.some((a) => a.subs.length || !LITERAL_PID_RE.test(a.text))) here.add(DYNAMIC_KILL);
      }
      if (viaXargs && (here.has("kill") || here.has(DYNAMIC_KILL))) return [true, seen]; // xargs feeds the kill PIDs from its input
      addAll(seen, here);
    }
  } catch (e) {
    if (e instanceof Refuse) return [true, seen];
    throw e;
  }
  return [false, seen];
}

// "" to allow, else the reason to refuse
function killByPattern(command) {
  if (command.length > MAX_INPUT) return "complex";
  let refuse, seen;
  try {
    [refuse, seen] = scan(command, [0, Date.now() + MAX_MS], 0);
  } catch (e) {
    if (e instanceof TooComplex) return "complex";
    throw e;
  }
  // a kill of a computed PID next to anything that finds PIDs: the PIDs may come from it, by a
  // pipe, a variable, read, mapfile or a loop, so refuse rather than follow every path
  return refuse || (seen.has(LISTER) && seen.has(DYNAMIC_KILL)) ? "pattern" : "";
}

function cmdKillguard() {
  let payload;
  try {
    payload = JSON.parse(fs.readFileSync(0, "utf8"));
  } catch {
    process.exit(0);
  }
  // only inside an idleflow run, from the cwd or the session's project folder; see cmd_killguard
  if (!payload) process.exit(0);
  const places = [payload.cwd || process.cwd(), process.env.CLAUDE_PROJECT_DIR || ""];
  if (places.every((p) => !p || findMap(p) === null)) process.exit(0);
  const cmd = (payload.tool_input || {}).command;
  const why = typeof cmd === "string" ? killByPattern(cmd) : "";
  if (why === "complex") {
    process.stderr.write("[idleflow] BLOCKED: this command is too long or too deeply nested to check for " +
      "kills by name or pattern. Split it, or write a long text with the Write tool.\n");
    process.exit(2);
  }
  if (why) {
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
function cmdClip(n, text) {
  n = parseInt(n, 10);
  const chars = Array.from(text); // code points, as Python counts them
  console.log(chars.length <= n ? text : chars.slice(0, n - 3).join("") + "...");
}
// Free means a server could take it now: a wildcard bind succeeds on IPv4 and, where the machine
// has it, IPv6 (a specific bind elsewhere makes it fail), and nothing answers on localhost.
function cmdPortFree(port) {
  const net = require("net");
  port = parseInt(port, 10);
  const bind = (host) => new Promise((done) => {
    const s = net.createServer();
    s.once("error", (e) => done(e.code));
    s.listen({ port, host, exclusive: true }, () => s.close(() => done(null)));
  });
  const answers = () => new Promise((done) => {
    const c = net.connect({ port, host: "127.0.0.1" });
    c.setTimeout(500, () => { c.destroy(); done(false); });
    c.once("connect", () => { c.destroy(); done(true); });
    c.once("error", () => done(false));
  });
  (async () => {
    const v4 = await bind("0.0.0.0");
    if (v4 !== null) process.exit(1);
    const v6 = await bind("::");
    if (v6 !== null && v6 !== "EADDRNOTAVAIL" && v6 !== "EAFNOSUPPORT") process.exit(1);
    process.exit((await answers()) ? 1 : 0);
  })();
}
const table = { get: cmdGet, set: cmdSet, inc: cmdInc, finish: cmdFinish, own: cmdOwn, gate: cmdGate, guard: cmdGuard, killguard: cmdKillguard, detach: cmdDetach, entries: cmdEntries, unowned: cmdUnowned, outside: cmdOutside, clip: cmdClip, "port-free": cmdPortFree };
const [cmd, ...args] = process.argv.slice(2);
if (!cmd || !(cmd in table)) {
  process.stderr.write(`idleflow.js: unknown subcommand ${JSON.stringify(cmd)}\n`);
  process.exit(1);
}
table[cmd](...args);
