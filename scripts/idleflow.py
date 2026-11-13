#!/usr/bin/env python3
"""idleflow helper (Python). scripts/idleflow.js is the same program in Node.

Both are kept identical in behaviour; rt.sh runs whichever runtime exists.
If you change a subcommand here, change it in idleflow.js too and run
scripts/selftest.sh with IDLEFLOW_RUNTIME=python and =node.

Subcommands:
  get    <file> <dotted.key>              print the value (strings raw, else JSON)
  set    <file> <dotted.key> <json>       set a value, creating parents
  inc    <file> <dotted.key> [n]          add n (default 1) to a number
  finish <file> <status> <log.jsonl>      stamp status+finished, append to log
  own    <file> <task-id> <worktree> <globs-json>
  gate   <limit> <slack> <numstat-all-file> <numstat-code-file> [uncommitted-paths-file]
  guard                                   hook: payload on stdin; exit 2 blocks
  killguard                               hook on Bash: payload on stdin; exit 2 blocks a kill by name or pattern
  detach <cwd> <log> <pidfile> <command>  runs the command in its own session, output to log; writes its pid
  entries <file> <key>                    one "name<TAB>value" line per entry of the object at that top-level key
  unowned <file> <task-id>                NUL-separated paths on stdin; prints those the task may not change
"""
import json
import os
import re
import sys
import datetime

WIN = os.name == "nt"


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save(path, obj):
    # LF and raw UTF-8 so the bytes match what idleflow.js writes, on every platform
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)
        f.write("\n")


def to_number(v):
    """Counters may have been written as strings by hand: accept 3, "3", "2.5";
    reject lists, objects, "abc", "Infinity" (identical rules in idleflow.js)."""
    if v is None or v == "":
        return 0
    if isinstance(v, bool) or not isinstance(v, (int, float, str)):
        bad(v)
    # plain decimal only: no hex, no underscores, no "Infinity"; same regex in idleflow.js
    if isinstance(v, str) and not re.match(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$", v.strip()):
        bad(v)
    try:
        f = float(v)
    except (TypeError, ValueError):
        bad(v)
    if f != f or f in (float("inf"), float("-inf")):
        bad(v)
    return int(f) if f.is_integer() else f


def bad(v):
    sys.stderr.write("idleflow: not a number: %s\n" % json.dumps(v))
    sys.exit(1)


def walk(obj, key, create):
    cur = obj
    parts = key.split(".")
    for k in parts[:-1]:
        if k not in cur or not isinstance(cur[k], dict):
            if not create:
                return None, None
            cur[k] = {}
        cur = cur[k]
    return cur, parts[-1]


def cmd_get(path, key):
    obj = load(path)
    cur, last = walk(obj, key, False)
    if cur is None or last not in cur:
        sys.exit(1)
    v = cur[last]
    print(v if isinstance(v, str) else json.dumps(v, separators=(",", ":"), ensure_ascii=False))


def cmd_set(path, key, val):
    obj = load(path)
    cur, last = walk(obj, key, True)
    cur[last] = json.loads(val)
    save(path, obj)


def cmd_inc(path, key, n="1"):
    obj = load(path)
    cur, last = walk(obj, key, True)
    total = to_number(cur.get(last)) + to_number(n)
    cur[last] = int(total) if float(total).is_integer() else total
    save(path, obj)
    print(cur[last])


def cmd_finish(path, status, log):
    r = load(path)
    r["status"] = status
    r["finished"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    save(path, r)
    with open(log, "a", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(r, ensure_ascii=False, separators=(",", ":")) + "\n")


def cmd_own(path, tid, wt, globs):
    o = load(path)
    o.setdefault("tasks", {})[tid] = {"worktree": wt, "owns": json.loads(globs)}
    save(path, o)


# --- gate -------------------------------------------------------------------

def parse_numstat(text):
    # `git diff -z --numstat`: "added<TAB>deleted<TAB>path<NUL>", or, for a rename, an empty path
    # followed by "old<NUL>new<NUL>". NUL-separated paths are never quoted, so any name arrives as is.
    toks = text.split("\0")
    rows, i = [], 0
    while i < len(toks):
        parts = toks[i].split("\t", 2)
        i += 1
        if len(parts) < 3:
            continue
        a, d, p = parts
        if p == "" and i + 1 < len(toks):
            p = toks[i + 1]
            i += 2
        a = 0 if a == "-" else int(a)  # binary files
        d = 0 if d == "-" else int(d)
        rows.append((p, a, d))
    return rows


def cmd_gate(limit, slack, all_file, code_file, uncommitted_file=None):
    limit, slack = int(limit), int(slack)
    with open(all_file, "r", encoding="utf-8", errors="replace") as f:
        all_rows = parse_numstat(f.read())
    with open(code_file, "r", encoding="utf-8", errors="replace") as f:
        code_rows = parse_numstat(f.read())
    added = sum(a for _, a, _ in code_rows)
    deleted = sum(d for _, _, d in code_rows)
    total = added + deleted
    excluded_total = sum(a + d for _, a, d in all_rows) - total
    if total <= limit:
        verdict = "ok"
    elif total <= limit + slack:
        verdict = "audit"
    else:
        verdict = "split"
    top = sorted(((p, a + d) for p, a, d in code_rows), key=lambda x: -x[1])[:8]
    uncommitted = []
    if uncommitted_file:
        with open(uncommitted_file, "r", encoding="utf-8", errors="replace") as f:
            # `git status -z --porcelain`: "XY path<NUL>"
            uncommitted = [r[3:] for r in f.read().split("\0") if len(r) > 3]
    # compact separators so the output is byte-identical to idleflow.js
    print(json.dumps({
        "added": added, "deleted": deleted, "total": total, "files": len(code_rows),
        "limit": limit, "slack": slack, "verdict": verdict,
        "excluded_total": excluded_total, "top": top,
        "uncommitted": len(uncommitted), "uncommitted_paths": uncommitted[:8],
    }, separators=(",", ":"), ensure_ascii=False))


# --- guard ------------------------------------------------------------------

def norm(p):
    """Absolute, forward-slash path with symlinks resolved, so a path through a link
    (macOS /var is /private/var) compares equal to the one git reports. On Windows also
    maps MSYS/Cygwin forms (/d/x, /cygdrive/d/x) to D:/x and lower-cases for comparison."""
    if not p:
        return ""
    if WIN:
        m = re.match(r"^/cygdrive/([A-Za-z])(/.*)?$", p) or re.match(r"^/([A-Za-z])(/.*)?$", p)
        if m:
            p = m.group(1).upper() + ":" + (m.group(2) or "/")
    p = os.path.realpath(p).replace("\\", "/")
    return p.lower() if WIN else p


def read_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read().strip()


def find_map(start):
    d = norm(start)
    while True:
        cand = os.path.join(d, ".idleflow", "runs", "active", "ownership.json")
        if os.path.isfile(cand):
            return cand
        marker = os.path.join(d, ".idleflow-run", "repo")
        if os.path.isfile(marker):
            try:
                cand = os.path.join(norm(read_text(marker)), ".idleflow", "runs", "active", "ownership.json")
                if os.path.isfile(cand):
                    return cand
            except Exception:
                pass
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def glob_regex(g):
    # Ownership globs: '*' and '?' are the only wildcards and both cross '/'. Everything else is
    # literal, brackets included: routes such as src/pages/[slug].astro are named with them.
    # Same in idleflow.js.
    return re.compile("".join(".*" if c == "*" else "." if c == "?" else re.escape(c) for c in g), re.S)


def glob_match(rel, globs):
    for g in globs:
        g = g.replace("\\", "/")
        if WIN:
            g = g.lower()
        if glob_regex(g).fullmatch(rel):
            return True
        if g.endswith("/**") and (rel == g[:-3] or rel.startswith(g[:-3] + "/")):
            return True
    return False


def cmd_guard():
    try:
        # bytes, not text: under -I on Windows sys.stdin would decode as cp1252 and a
        # non-ASCII worktree path would then match nothing, so the guard would fail open
        payload = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    except Exception:
        sys.exit(0)
    tool_input = payload.get("tool_input") or {}
    raw = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
    if not raw:
        sys.exit(0)
    path = norm(raw)
    cwd = payload.get("cwd") or os.getcwd()

    mp = find_map(os.path.dirname(path)) or find_map(cwd)
    if mp is None:
        sys.exit(0)
    try:
        omap = load(mp)
    except Exception:
        sys.exit(0)

    # The run's own state is never edited through the editing tools: the orchestrator goes
    # through run.sh, and a task that could rewrite ownership.json, run.json or a worktree
    # marker could grant itself globs, approve itself, or make this guard find no map.
    name = os.path.basename(path)
    if "/.idleflow/runs/" in path and name in ("ownership.json", "run.json", "gate.json"):
        sys.stderr.write("[idleflow] BLOCKED: %s is run state; use scripts/run.sh (set, own, inc) instead.\n" % name)
        sys.exit(2)
    if "/.idleflow-run/" in path and name != "result.md":
        sys.stderr.write("[idleflow] BLOCKED: %s is a worktree marker; only .idleflow-run/result.md may be written.\n" % name)
        sys.exit(2)

    for tid, t in (omap.get("tasks") or {}).items():
        wt = norm(t.get("worktree", ""))
        if not wt:
            continue
        if path == wt or path.startswith(wt + "/"):
            rel = path[len(wt) + 1:] if path != wt else ""
            owns = t.get("owns") or []
            implicit = [".idleflow-run/result.md"] + list(omap.get("shared") or [])
            if glob_match(rel, list(owns) + implicit):
                sys.exit(0)
            sys.stderr.write(
                "[idleflow] BLOCKED: %s is not owned by task %s.\n"
                "Owned globs: %s\n"
                "If this file must change, stop and report it in your task report under "
                "'blocked_on' so the orchestrator can reassign ownership. Do not work around this.\n"
                % (rel, tid, json.dumps(owns))
            )
            sys.exit(2)

    # Not in a worktree. While tasks are building, the main checkout is off limits for code:
    # an implementer that forgot to cd would otherwise write where no reviewer looks.
    repo = norm(omap.get("repo", ""))
    if repo and (path == repo or path.startswith(repo + "/")) and building(os.path.dirname(mp)):
        rel = path[len(repo) + 1:] if path != repo else ""
        if not orchestrator_file(rel):
            sys.stderr.write(
                "[idleflow] BLOCKED: %s is in the main checkout while tasks are building.\n"
                "Implementers edit only inside their worktree; the orchestrator edits only "
                ".idleflow/runs/**, .idleflow/lessons.md and suggestions.md, docs/**, root *.md and .gitignore during the build.\n" % rel
            )
            sys.exit(2)
    sys.exit(0)


def building(run_dir):
    """True while any task in run.json has status "building"."""
    try:
        run = load(os.path.join(run_dir, "run.json"))
    except Exception:
        return False
    for t in (run.get("tasks") or {}).values():
        if isinstance(t, dict) and t.get("status") == "building":
            return True
    return False


def orchestrator_file(rel):
    """Paths the orchestrator may write in the main checkout mid-build."""
    return (
        rel.startswith(".idleflow/runs/")
        or rel in (".idleflow/lessons.md", ".idleflow/suggestions.md")
        or rel.startswith("docs/") or rel == ".gitignore"
        or ("/" not in rel and rel.endswith(".md"))
    )


def cmd_detach(cwd, log, pidfile, command):
    # A new session: a caller that exits (a command substitution, a hook) must not take the server with it.
    import subprocess
    with open(log, "w", encoding="utf-8") as out:
        proc = subprocess.Popen(["bash", "-c", command], cwd=cwd, stdin=subprocess.DEVNULL,
                                stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
    with open(pidfile, "w", encoding="utf-8") as f:
        f.write(str(proc.pid))


def cmd_entries(path, key):
    try:
        obj = load(path)
    except Exception:
        return
    section = obj.get(key) if isinstance(obj, dict) else None
    if not isinstance(section, dict):
        return
    for name, value in section.items():
        text = value if isinstance(value, str) else json.dumps(value, separators=(",", ":"), ensure_ascii=False)
        print("%s\t%s" % (name, text.replace("\t", " ").replace("\n", " ")))


def cmd_unowned(path, tid):
    # The reviewers' ownership check, with the guard's matcher, so the two can never disagree.
    omap = load(path)
    task = (omap.get("tasks") or {}).get(tid)
    if task is None:
        sys.stderr.write("idleflow.py: task %s is not in %s\n" % (tid, path))
        sys.exit(1)
    allowed = list(task.get("owns") or []) + [".idleflow-run/**"] + list(omap.get("shared") or [])
    # paths come NUL-separated (`git diff -z --name-only`), so none is quoted. git separates folders
    # with `/` on every OS; a `\` is part of a name and is kept, or `src\x.py` would pass as `src/x.py`.
    for rel in sys.stdin.buffer.read().decode("utf-8", "replace").split("\0"):
        if rel and not glob_match(rel.lower() if WIN else rel, allowed):
            print(rel)


# --- kill guard ---------------------------------------------------------------
# A kill by name or pattern matches every process on the machine with that text, other Claude Code
# sessions' included, so only a kill of a PID the agent kept is allowed. The command is read the way
# a shell reads it: quoted text and here-document bodies are data; $(...), backticks, `bash -c`,
# `eval` and `watch` hold commands. Same in idleflow.js; the two must agree on every input.

SHELLS = ("bash", "sh", "zsh", "dash", "ksh")
# words that start a command without being its program
KEYWORDS = ("then", "do", "else", "elif", "if", "while", "until", "!", "{", "}", "time", "coproc")
# compound commands: a statement runs on to its closing word, so a whole loop is one statement
OPENERS = ("if", "while", "until", "for", "select", "case")
CLOSERS = ("fi", "done", "esac")
HEADERS = ("for", "select", "case", "in", "esac")  # their words are a list, not a command
# wrapper -> (short options that take a value, long options that take a value, words before the command)
WRAPPERS = {
    "sudo": ("ugChpUrtTD", ("user", "group", "host", "prompt", "close-from", "role", "type"), 0),
    "doas": ("uC", (), 0), "exec": ("a", (), 0), "command": ("", (), 0), "builtin": ("", (), 0),
    "nohup": ("", (), 0), "env": ("uSCP", ("unset", "chdir", "split-string"), 0),
    "nice": ("n", ("adjustment",), 0), "ionice": ("cnp", ("class", "classdata", "pid"), 0),
    "timeout": ("sk", ("signal", "kill-after"), 1), "stdbuf": ("ioe", ("input", "output", "error"), 0),
    "setsid": ("", (), 0),
    "xargs": ("IinPLdsaE", ("replace", "max-args", "max-procs", "max-lines", "delimiter", "max-chars",
                            "arg-file", "eof"), 0),
    "chrt": ("", (), 1), "taskset": ("", (), 1), "strace": ("eoOpPsSuUXba", (), 0), "unbuffer": ("", (), 0),
    "flock": ("Ew", ("conflict-exit-code", "wait", "timeout"), 1),
    "runuser": ("ugGw", ("user", "group", "supp-group", "whitelist-environment"), 0),
    "systemd-run": ("upE", ("unit", "property", "setenv", "uid", "gid", "slice", "description"), 0),
    "npx": ("p", ("package", "call"), 0), "bunx": ("p", ("package",), 0),
}
# programs that run the word after a -c option (or --command) as a shell script
SCRIPT_OPTION = ("su", "runuser", "script", "flock")
NAME_KILLERS = ("pkill", "killall", "killall5", "skill", "kill-port", "fkill", "fkill-cli")
PID_LISTERS = ("pgrep", "pidof", "ps", "lsof", "fuser", "ss", "netstat")
MAX_DEPTH, MAX_WORK = 12, 50000
ASSIGN_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\+?=")


class _TooComplex(Exception):
    pass


def _close(s, i):
    # index just past the end of the "$(" or backtick that starts at s[i]; quotes and nesting respected
    if s[i] == "`":
        j = i + 1
        while j < len(s) and s[j] != "`":
            j += 2 if s[j] == "\\" else 1
        return min(j + 1, len(s))
    depth, j = 1, i + 2
    while j < len(s) and depth:
        c = s[j]
        if c == "\\":
            j += 2
        elif c == "'":
            k = s.find("'", j + 1)
            j = len(s) if k < 0 else k + 1
        elif c == '"':
            j += 1
            while j < len(s) and s[j] != '"':
                j += 2 if s[j] == "\\" else 1
            j += 1
        elif s.startswith("$(", j):
            depth += 1
            j += 2
        else:
            if c == ")":
                depth -= 1
            j += 1
    return min(j, len(s))


def _inner(s, i):
    # (the script inside the "$(" or backtick at s[i], the index past its end)
    k = _close(s, i)
    return (s[i + 2:k - 1] if s[i] == "$" else s[i + 1:k - 1]), k


def _lex(s, work):
    # The commands of one script, nothing nested parsed yet. A command is a dict: "words" (each a
    # dict with "text" and "subs", the raw $(...)/backtick scripts in it), "subs" (from redirection
    # targets), "docs" (here-document bodies, each (body, delimiter_was_quoted)) and "stmt", the
    # statement it belongs to: a pipeline, or a whole compound command such as a loop.
    work[0] += len(s)
    if work[0] > MAX_WORK:
        raise _TooComplex()
    cmds, stmt, compound, pending = [], 0, 0, []
    st = {"cmd": {"words": [], "subs": [], "docs": [], "stmt": 0}, "word": None, "redirect": False}

    def w():
        if st["word"] is None:
            st["word"] = {"text": "", "subs": []}
        return st["word"]

    def end_word():
        word = st["word"]
        if word is not None:
            if st["redirect"]:
                st["cmd"]["subs"].extend(word["subs"])  # a redirection target is not an argument
                st["redirect"] = False
            else:
                st["cmd"]["words"].append(word)
        st["word"] = None

    def end_cmd(boundary):
        nonlocal stmt, compound
        end_word()
        cmd = st["cmd"]
        if cmd["words"] or cmd["subs"] or cmd["docs"]:
            first = cmd["words"][0]["text"] if cmd["words"] else ""
            cmd["stmt"] = stmt
            cmds.append(cmd)
            compound = max(0, compound + (first in OPENERS) - (first in CLOSERS))
        if boundary and compound == 0:
            stmt += 1
        st["cmd"] = {"words": [], "subs": [], "docs": [], "stmt": stmt}

    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c in " \t":
            end_word()
            i += 1
        elif c == "\n":
            end_cmd(True)
            i += 1
            for delim, quoted, strip, owner in pending:
                body = []
                while i < n:
                    k = s.find("\n", i)
                    k = n if k < 0 else k
                    line, i = s[i:k], k + 1
                    if (line.lstrip("\t") if strip else line) == delim:
                        break
                    body.append(line)
                owner["docs"].append(("\n".join(body), quoted))
            pending = []
        elif c == "&" and s[i + 1:i + 2] == ">":
            end_word()
            i += 2
            st["redirect"] = True
        elif c in ";&|()":
            two = s[i:i + 2]
            end_cmd(c != "|" or two == "||")
            i += 2 if two in ("&&", "||", ";;") else 1
        elif c in "<>":
            word = st["word"]
            if word is not None and word["text"].isdigit() and not word["subs"]:
                st["word"] = None  # a file descriptor number, as in 2>&1
            end_word()
            if s.startswith("<<", i) and not s.startswith("<<<", i):
                j = i + 2
                strip = s[j:j + 1] == "-"
                j += 1 if strip else 0
                while j < n and s[j] in " \t":
                    j += 1
                k = j
                while k < n and s[k] not in " \t\n;&|()<>":
                    k += 1
                raw = s[j:k]
                quoted = any(q in raw for q in "'\"\\")
                pending.append((raw.replace("'", "").replace('"', "").replace("\\", ""), quoted, strip, st["cmd"]))
                i = k
            else:
                while i < n and s[i] in "<>&|":
                    i += 1
                st["redirect"] = True
        elif c == "#" and st["word"] is None:
            k = s.find("\n", i)
            i = n if k < 0 else k
        elif c == "\\":
            if s[i + 1:i + 2] != "\n":
                w()["text"] += s[i + 1:i + 2]
            i += 2
        elif c == "'" or (c == "$" and s[i + 1:i + 2] == "'"):
            ansi = c == "$"
            j = i + 2 if ansi else i + 1
            while j < n and s[j] != "'":
                if ansi and s[j] == "\\":
                    w()["text"] += {"n": "\n", "t": "\t"}.get(s[j + 1:j + 2], s[j + 1:j + 2])
                    j += 2
                else:
                    w()["text"] += s[j]
                    j += 1
            w()
            i = j + 1
        elif c == '"' or (c == "$" and s[i + 1:i + 2] == '"'):
            j = i + 2 if c == "$" else i + 1
            while j < n and s[j] != '"':
                if s[j] == "\\":
                    w()["text"] += s[j + 1:j + 2]
                    j += 2
                elif s.startswith("$(", j) or s[j] == "`":
                    inner, k = _inner(s, j)
                    w()["subs"].append(inner)
                    w()["text"] += s[j:k]
                    j = k
                else:
                    w()["text"] += s[j]
                    j += 1
            w()
            i = j + 1
        elif s.startswith("$(", i) or c == "`":
            inner, k = _inner(s, i)
            w()["subs"].append(inner)
            w()["text"] += s[i:k]
            i = k
        else:
            w()["text"] += c
            i += 1
    end_cmd(True)
    return cmds


def _skip_options(words, i, short_takes, long_takes):
    # index of the first word after the options that start at words[i]
    while i < len(words):
        t = words[i]["text"]
        if t == "--":
            return i + 1
        if not t.startswith("-") or t == "-":
            return i
        i += 1
        if t.startswith("--"):
            if "=" not in t and t[2:] in long_takes:
                i += 1
        elif t[-1] in short_takes:
            i += 1  # the value of the cluster's last letter: -u root, -iu root
    return i


def _script_after_c(words):
    # index of the word after a short-option cluster holding "c" (-c, -lc, -qc) or after --command
    for k, wd in enumerate(words):
        t = wd["text"]
        if t == "--":
            return -1
        if t == "--command" or (t.startswith("-") and not t.startswith("--") and "c" in t[1:]):
            return k + 1 if k + 1 < len(words) else -1
        if not t.startswith("-"):
            return -1
    return -1


def _program(words):
    # (name, its words, whether xargs runs it, the indexes of `rest` that hold a script it runs)
    via_xargs, i = False, 0
    while i < len(words):
        t = words[i]["text"]
        if t in KEYWORDS or ASSIGN_RE.match(t):
            i += 1
            continue
        name, rest = os.path.basename(t), words[i:]
        if name in SHELLS or name in SCRIPT_OPTION:
            k = _script_after_c(rest[1:])
            if k >= 0:
                return name, rest, via_xargs, [1 + k]
            if name in SHELLS:
                return name, rest, via_xargs, []
        if name in ("eval", "watch"):
            start = _skip_options(rest, 1, "nd" if name == "watch" else "", ("interval", "differences"))
            return name, rest, via_xargs, list(range(start, len(rest)))
        if name in ("pnpm", "yarn") and len(rest) > 1 and rest[1]["text"] == "dlx":
            i += 2
            continue
        if name not in WRAPPERS:
            return name, rest, via_xargs, []
        short_takes, long_takes, positional = WRAPPERS[name]
        via_xargs = via_xargs or name == "xargs"
        options_end = _skip_options(words, i + 1, short_takes, long_takes)
        if name == "taskset" and any(wd["text"] in ("-c", "-p", "--cpu-list", "--pid") for wd in rest[1:]):
            positional = 0 if any(wd["text"] in ("-p", "--pid") for wd in rest[1:]) else 1
        i = options_end + positional
    return "", [], via_xargs, []


def _kills_all(args):
    # PID -1 signals every process the user may signal
    signal = False
    for k, wd in enumerate(args):
        t = wd["text"]
        if t == "--":
            return any(a["text"] == "-1" for a in args[k + 1:])
        if t == "-1" and signal:
            return True
        if t.startswith("-") and t not in ("-l", "-L"):
            signal = True
    return False


def _lists_pids(programs):
    return any(p in PID_LISTERS for p in programs)


def _scan(script, work, depth):
    # (refuse, the programs this script and everything nested in it run)
    if depth > MAX_DEPTH:
        raise _TooComplex()
    seen, stmt_programs, tainted, kills = set(), {}, set(), []

    def nested(sub):
        refuse, progs = _scan(sub, work, depth + 1)
        if refuse:
            raise _Refuse()
        return progs

    try:
        for cmd in _lex(script, work):
            words = cmd["words"]
            name, rest, via_xargs, script_at = "", [], False, []
            if words and words[0]["text"] not in HEADERS:
                name, rest, via_xargs, script_at = _program(words)
            here = {name} if name else set()
            script_words = {id(rest[k]) for k in script_at}
            if script_at:
                here |= nested(" ".join(rest[k]["text"] for k in script_at))
            word_programs = {}
            for wd in words:
                if id(wd) in script_words:
                    continue  # its substitutions are part of the script just read
                progs = set()
                for sub in wd["subs"]:
                    progs |= nested(sub)
                word_programs[id(wd)] = progs
                here |= progs
            for sub in cmd["subs"]:
                here |= nested(sub)
            for body, quoted in cmd["docs"]:
                if name in SHELLS and not script_at:
                    here |= nested(body)  # bash <<EOF: the body is the script
                elif not quoted:
                    k = 0
                    while k < len(body):
                        if body.startswith("$(", k) or body[k] == "`":
                            inner, k = _inner(body, k)
                            here |= nested(inner)
                        else:
                            k += 1
            if name in NAME_KILLERS:
                return True, seen
            args = rest[1:]
            if name == "fuser" and any(
                    a["text"] == "--kill" or (a["text"].startswith("-") and not a["text"].startswith("--")
                                              and "k" in a["text"]) for a in args):
                return True, seen
            if name == "find":
                texts = [a["text"] for a in args]
                for k, t in enumerate(texts):
                    if t in ("-exec", "-execdir", "-ok", "-okdir"):
                        end = next((m for m in range(k + 1, len(texts)) if texts[m] in (";", "+")), len(texts))
                        inner = _program(args[k + 1:end])[0]
                        if inner in NAME_KILLERS or inner == "kill":
                            return True, seen
            for wd in words:
                m = ASSIGN_RE.match(wd["text"])
                if m and _lists_pids(word_programs.get(id(wd), ())):
                    tainted.add(m.group(1))
            if name == "kill":
                if via_xargs or _kills_all(args) or any(_lists_pids(word_programs.get(id(a), ())) for a in args):
                    return True, seen
                kills.append((cmd["stmt"], args))
            stmt_programs.setdefault(cmd["stmt"], set()).update(here)
            seen |= here
    except _Refuse:
        return True, seen
    for stmt, args in kills:
        if _lists_pids(stmt_programs.get(stmt, ())):
            return True, seen  # pgrep x | while read p; do kill $p; done, and loops over $(pgrep x)
        for a in args:
            if any(re.search(r"\$\{?" + v + r"\b", a["text"]) for v in tainted):
                return True, seen  # pids=$(pgrep x); kill $pids
    return False, seen


class _Refuse(Exception):
    pass


def kill_by_pattern(command):
    try:
        return _scan(command, [0], 0)[0]
    except _TooComplex:
        return True  # too deeply nested or too long to read: refuse rather than guess


def cmd_killguard():
    try:
        payload = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
        cmd = (payload.get("tool_input") or {}).get("command")
    except Exception:
        sys.exit(0)
    if isinstance(cmd, str) and kill_by_pattern(cmd):
        sys.stderr.write(
            "[idleflow] BLOCKED: this ends processes by name or pattern, which also ends other "
            "sessions' work on this machine. End only a process you started, by the PID you kept "
            "(kill <pid>, or kill -- -<pid> for its group); give a command that may hang the Bash "
            "tool's timeout instead of killing it afterwards.\n")
        sys.exit(2)
    sys.exit(0)


def main(argv):
    # -I (isolated mode) ignores PYTHONUTF8, so on Windows stdout/stderr would be cp1252
    # and a BLOCKED message with a non-ASCII filename would come out garbled.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if not argv:
        sys.stderr.write(__doc__)
        sys.exit(1)
    cmd, args = argv[0], argv[1:]
    table = {
        "get": cmd_get, "set": cmd_set, "inc": cmd_inc, "finish": cmd_finish,
        "own": cmd_own, "gate": cmd_gate, "guard": cmd_guard, "killguard": cmd_killguard, "detach": cmd_detach, "entries": cmd_entries,
        "unowned": cmd_unowned,
    }
    if cmd not in table:
        sys.stderr.write("idleflow.py: unknown subcommand %r\n" % cmd)
        sys.exit(1)
    table[cmd](*args)


if __name__ == "__main__":
    main(sys.argv[1:])
