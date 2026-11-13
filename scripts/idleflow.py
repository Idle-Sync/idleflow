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


# A kill by name or pattern matches every process on the machine with that text, other Claude Code
# sessions' included, so only a kill by a PID the agent kept is allowed. Same in idleflow.js.
KILL_BY_PATTERN = [
    # in command position: at the start, after ; & | ( or a backtick, or after sudo, exec or xargs
    r"(^|[;&|`(]\s*|\b(sudo|exec)\s+|\bxargs\s+(-\S+\s+)*)(pkill|killall)\b",
    r"(^|[;&|`(]\s*|\b(sudo|exec)\s+)kill\b[^;&|\n]*(\$\(|`)\s*(pgrep|pidof)\b",
    r"\b(pgrep|pidof)\b[^;&\n]*\|\s*(sudo\s+)?xargs\b[^;&|\n]*\bkill\b",
    r"(^|[;&|`(]\s*|\b(sudo|exec)\s+)fuser\b[^;&|\n]*\s-[a-zA-Z]*k",
]


def cmd_killguard():
    try:
        payload = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
    except Exception:
        sys.exit(0)
    cmd = (payload.get("tool_input") or {}).get("command") or ""
    for pat in KILL_BY_PATTERN:
        if re.search(pat, cmd):
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
