#!/usr/bin/env bash
# End-to-end check of the scripts in a throwaway repo. No agents, no Claude.
#
#   bash scripts/selftest.sh                      # whichever runtime rt.sh picks
#   IDLEFLOW_RUNTIME=node   bash scripts/selftest.sh
#   IDLEFLOW_RUNTIME=python bash scripts/selftest.sh
#
# Exercises: new, wt add, own, guard (blocked + allowed, with POSIX and native paths),
# gate (ok and split, with excludes), set/inc, merge, finish, and a second `new` that
# parks a leftover run. Exit 0 and a final "PASS" line mean everything worked.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$HERE/run.sh"
GUARD="$HERE/ownership-guard.sh"
# shellcheck source=/dev/null
source "$HERE/rt.sh"

fails=0
ok()   { echo "  ok    $1"; }
fail() { echo "  FAIL  $1"; fails=$((fails+1)); }
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }

native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
guard_rc() { # guard_rc <file_path> <cwd>  -> exit code of the hook
  printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s","content":"x"}}' "$2" "$1" | bash "$GUARD" 2>/dev/null
  echo $?
}
json_esc() { echo "$1" | sed 's/\\/\\\\/g'; }

echo "runtime: $(idleflow_rt_name)"
d="$(mktemp -d)"; d="$(cd "$d" && pwd)"
cleanup() { cd / ; rm -rf "$d" "${d}__wt" 2>/dev/null || true; }
trap cleanup EXIT

cd "$d" && git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p src && echo 'a' > src/a.txt && git add . && git -c user.name=t -c user.email=t@t commit -qm base

echo "--- new / set / inc"
id="$(bash "$RUN" new "self test")"
check "new prints an id"               '[ -n "$id" ]'
check "active/run.json exists"         '[ -f .claude/runs/active/run.json ]'
check ".gitignore has runs/"           'grep -qx ".claude/runs/" .gitignore'
bash "$RUN" set size '"M"'
check "set size"                       '[ "$(idleflow_rt get .claude/runs/active/run.json size)" = "M" ]'
bash "$RUN" set tasks.T1.status '"building"'
check "set nested key"                 '[ "$(idleflow_rt get .claude/runs/active/run.json tasks.T1.status)" = "building" ]'
check "inc retries -> 1"               '[ "$(bash "$RUN" inc retries)" = "1" ]'
check "inc review_findings 3 -> 3"     '[ "$(bash "$RUN" inc review_findings 3)" = "3" ]'

echo "--- worktree / ownership"
wt="$(bash "$RUN" wt add T1)"
check "wt add prints path"             '[ -n "$wt" ] && [ -d "$wt" ]'
check "wt on task branch"              'git -C "$wt" rev-parse --abbrev-ref HEAD | grep -q "^idleflow/$id/T1$"'
check "wt marker written"              '[ "$(cat "$wt/.claude-run/task-id")" = "T1" ]'
bash "$RUN" own T1 '["src/**","tests/**"]'
check "ownership recorded"             'idleflow_rt get .claude/runs/active/ownership.json tasks.T1.owns | grep -q "src/\*\*"'

echo "--- guard"
wtn="$(native "$wt")"; dn="$(native "$d")"
check "blocks unowned file (native path)" '[ "$(guard_rc "$(json_esc "$wtn/other.txt")" "$(json_esc "$wtn")")" = "2" ]'
check "blocks unowned file (posix path)"  '[ "$(guard_rc "$wt/other.txt" "$wt")" = "2" ]'
check "allows owned file"                 '[ "$(guard_rc "$(json_esc "$wtn/src/new.txt")" "$(json_esc "$wtn")")" = "0" ]'
check "allows owned nested file"          '[ "$(guard_rc "$(json_esc "$wtn/tests/a/b/c.txt")" "$(json_esc "$wtn")")" = "0" ]'
check "allows .claude-run report"         '[ "$(guard_rc "$(json_esc "$wtn/.claude-run/report.md")" "$(json_esc "$wtn")")" = "0" ]'
check "allows main checkout"              '[ "$(guard_rc "$(json_esc "$dn/plan.md")" "$(json_esc "$dn")")" = "0" ]'
check "allows outside any repo"           '[ "$(guard_rc "/nowhere/x.txt" "/nowhere")" = "0" ]'
check "allows on garbage payload"         '[ "$(echo "not json" | bash "$GUARD" 2>/dev/null; echo $?)" = "0" ]'
if [ -n "${IDLEFLOW_RUNTIME:-}" ]; then
  check "no-runtime still allows"         '[ "$(printf "{}" | IDLEFLOW_RUNTIME=/no/such/bin bash "$GUARD" 2>/dev/null; echo $?)" = "0" ]'
fi

echo "--- gate"
( cd "$wt" && printf 'x\ny\nz\n' > src/code.py && printf '%s\n' $(seq 1 50) > README.md )
g="$(bash "$RUN" gate T1)"
check "gate verdict ok"                'echo "$g" | grep -q "\"verdict\":\"ok\""'
check "gate counts code lines (3)"     'echo "$g" | grep -q "\"total\":3,"'
check "gate excludes .md (50)"         'echo "$g" | grep -q "\"excluded_total\":50"'
check "gate.json written"              '[ -f .claude/runs/active/tasks/T1/gate.json ]'
( cd "$wt" && seq 1 40 > src/big.py )
g2="$("$HERE/diff-gate.sh" "$wt" "$(git rev-parse HEAD)" 10 5)"
check "gate verdict split past slack"  'echo "$g2" | grep -q "\"verdict\":\"split\""'
g3="$("$HERE/diff-gate.sh" "$wt" "$(git rev-parse HEAD)" 40 5)"
check "gate verdict audit in slack"    'echo "$g3" | grep -q "\"verdict\":\"audit\""'

echo "--- merge / finish"
m="$(bash "$RUN" merge T1)"
check "merge reports merged"           '[ "$m" = "merged T1" ]'
check "merged file on main"            '[ -f src/code.py ]'
bash "$RUN" wt rm T1
check "wt removed"                     '[ ! -d "$wt" ]'
f="$(bash "$RUN" finish done)"
check "finish message"                 'echo "$f" | grep -q "finished: done"'
check "active renamed to id"           '[ ! -e .claude/runs/active ] && [ -f ".claude/runs/$id/run.json" ]'
check "log.jsonl appended"             'grep -q "\"id\": *\"$id\"" .claude/runs/log.jsonl'
check "status in run.json"             '[ "$(idleflow_rt get ".claude/runs/$id/run.json" status)" = "done" ]'

echo "--- leftover run is parked by next new"
id2="$(bash "$RUN" new second 2>/dev/null)"
id3="$(bash "$RUN" new third 2>/dev/null)"
check "second run parked"              '[ -f ".claude/runs/$id2/run.json" ] && [ "$(idleflow_rt get ".claude/runs/$id2/run.json" status)" = "abandoned" ]'
check "third run active"               '[ "$(idleflow_rt get .claude/runs/active/run.json id)" = "$id3" ]'
bash "$RUN" finish test >/dev/null

echo "--- conf"
check "conf prints runtime"            'bash "$RUN" conf | grep -q "^RUNTIME="'

echo
if [ "$fails" -eq 0 ]; then echo "PASS ($(idleflow_rt_name))"; else echo "FAIL: $fails check(s)"; exit 1; fi
