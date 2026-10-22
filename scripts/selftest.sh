#!/usr/bin/env bash
# End-to-end check of the scripts in a throwaway repo. No agents, no Claude.
#
#   bash scripts/selftest.sh                      # whichever runtime rt.sh picks
#   IDLEFLOW_RUNTIME=node   bash scripts/selftest.sh
#   IDLEFLOW_RUNTIME=python bash scripts/selftest.sh
#
# Exercises: new (on a repo with no commits, with a slug that needs JSON escaping),
# snapshot (unborn branch, gitignored docs/, unrelated staged work left alone, human
# identity kept), wt add, own, guard (blocked + allowed, POSIX and native paths, a
# non-ASCII worktree, main checkout during build), report, gate (ok / audit / split,
# excludes, empty DIFF_EXCLUDE, bad base, per-task base after an earlier merge),
# get / set / inc (parity cases), merge (conflict → 3, unknown branch → 4), wt rm after
# finish, finish, a runtime given as a full path, a second `new` that parks a
# leftover run, ignore (info/exclude until conventions say gitignore, no duplicates),
# and prompt contracts (the stack scan, researcher and R3 agree on research units,
# budget and reply counts; setup steps follow the classifier's risk and dependency
# fields; ignore rules go through run.sh ignore). Exit 0 and a final "PASS" line mean everything worked.

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
json_esc() { echo "$1" | sed 's/\\/\\\\/g'; }
guard_rc() { # guard_rc <file_path> <cwd>  -> exit code of the hook
  printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s","content":"x"}}' "$(json_esc "$2")" "$(json_esc "$1")" | bash "$GUARD" 2>/dev/null
  echo $?
}
commit() { git -c user.name=t -c user.email=t@t commit -q "$@"; }

echo "runtime: $(idleflow_rt_name)"
d="$(mktemp -d)"; d="$(cd "$d" && pwd)"
cleanup() { cd / ; rm -rf "$d" "${d}__wt" 2>/dev/null || true; }
trap cleanup EXIT

echo "--- new on a repo with no commits (what /idleflow:init does)"
cd "$d" && git init -q && git config user.name "Human" && git config user.email "human@example.com"
id0="$(bash "$RUN" new 'fix "quoted" thing' 2>/dev/null)"
check "new works on an unborn branch"     '[ -n "$id0" ] && [ -f .claude/runs/active/run.json ]'
check "slug with quotes is valid JSON"    '[ "$(bash "$RUN" get slug)" = "fix-quoted-thing" ]'
check "base_sha empty before first commit" '[ "$(bash "$RUN" get base_sha)" = "" ]'
check "wt add refuses without a commit"   '! bash "$RUN" wt add T0 2>/dev/null'
check "gate refuses without a base"       '! bash "$RUN" gate T0 2>/dev/null'
check "new ignores runs/ locally until asked" 'grep -qxF ".claude/runs/" .git/info/exclude && [ ! -e .gitignore ]'
check "ignore defaults to info/exclude"   'bash "$RUN" ignore "scratch-a/" >/dev/null && bash "$RUN" ignore "scratch-a/" >/dev/null && [ "$(grep -cxF "scratch-a/" .git/info/exclude)" = "1" ] && [ ! -e .gitignore ]'
printf '# proj\n' > README.md; mkdir -p .claude docs/research; printf 'mode: balanced\n' > .claude/conventions.md; printf 'r\n' > docs/research/x.md
printf 'docs/\n' > .gitignore
printf 'unrelated\n' > unrelated.txt; git add unrelated.txt
s="$(bash "$RUN" snapshot)"
check "snapshot commits on unborn branch" 'echo "$s" | grep -q "committed" && git log --oneline | grep -q "project conventions"'
check "snapshot skips gitignored docs/"   '! git ls-files --error-unmatch docs/research/x.md >/dev/null 2>&1'
check "snapshot leaves other staged work" 'git diff --cached --name-only | grep -qx "unrelated.txt"'
check "snapshot keeps the human identity" '[ "$(git log -1 --format=%an)" = "Human" ]'
check "snapshot is a no-op when clean"    '[ "$(bash "$RUN" snapshot)" = "snapshot: nothing to commit" ]'
git reset -q unrelated.txt; rm -f unrelated.txt; printf '.claude/runs/\n' > .gitignore; git add .gitignore; commit -m gitignore
bash "$RUN" finish setup >/dev/null

printf 'ignore_in: gitignore\n' >> .claude/conventions.md
mkdir -p src && echo 'a' > src/a.txt && git add . && commit -m base

printf 'node_modules/' > .gitignore   # no trailing newline on purpose
echo "--- new / get / set / inc"
id="$(bash "$RUN" new "self test" 2>/dev/null)"
check ".gitignore newline repaired"    '[ "$(wc -l < .gitignore | tr -d " ")" = "2" ] && grep -qx "node_modules/" .gitignore'
check "new prints an id"               '[ -n "$id" ]'
check "active/run.json exists"         '[ -f .claude/runs/active/run.json ]'
check ".gitignore has runs/ when ignore_in: gitignore" 'grep -qx ".claude/runs/" .gitignore'
check "ignore follows ignore_in: gitignore" 'bash "$RUN" ignore "scratch-b/" >/dev/null && bash "$RUN" ignore "scratch-b/" >/dev/null && [ "$(grep -cxF "scratch-b/" .gitignore)" = "1" ] && ! grep -qxF "scratch-b/" .git/info/exclude'
bash "$RUN" set size '"M"'
check "get/set size"                   '[ "$(bash "$RUN" get size)" = "M" ]'
bash "$RUN" set tasks.T1.status '"building"'
check "set nested key"                 '[ "$(bash "$RUN" get tasks.T1.status)" = "building" ]'
check "get non-string is compact JSON" '[ "$(bash "$RUN" get tasks)" = "{\"T1\":{\"status\":\"building\"}}" ]'
check "inc retries -> 1"               '[ "$(bash "$RUN" inc retries)" = "1" ]'
check "inc review_findings 3 -> 3"     '[ "$(bash "$RUN" inc review_findings 3)" = "3" ]'
bash "$RUN" set gate_trips '"2"'
check "inc coerces a string counter"   '[ "$(bash "$RUN" inc gate_trips)" = "3" ]'
bash "$RUN" set gate_trips 2.0
check "inc 2.0 + 1 prints 3"           '[ "$(bash "$RUN" inc gate_trips)" = "3" ]'
for v in '"abc"' '[]' '{}' 'true' '"Infinity"' '"0x10"' '"1_000"'; do
  bash "$RUN" set gate_trips "$v"
  check "inc rejects $v"               '! bash "$RUN" inc gate_trips 2>/dev/null'
done
bash "$RUN" set gate_trips 0
scratch="$d/.claude/runs"   # gitignored, so scratch files never become tracked
cp .claude/runs/active/run.json "$scratch/run.bak"; bash "$RUN" set id '""'
check "finish refuses an empty id"     '! bash "$RUN" finish x 2>/dev/null && [ -d .claude/runs/active ]'
cp "$scratch/run.bak" .claude/runs/active/run.json
check "run.json has no CRLF"           '! grep -q $'"'"'\r'"'"' .claude/runs/active/run.json'

echo "--- worktree / ownership"
wt="$(bash "$RUN" wt add T1)"
check "wt add prints path"             '[ -n "$wt" ] && [ -d "$wt" ]'
check "wt on task branch"              'git -C "$wt" rev-parse --abbrev-ref HEAD | grep -q "^idleflow/$id/T1$"'
check "wt marker written"              '[ "$(cat "$wt/.claude-run/task-id")" = "T1" ]'
check "task base_sha recorded"         '[ "$(bash "$RUN" get tasks.T1.base_sha)" = "$(git rev-parse HEAD)" ]'
wt_again="$(bash "$RUN" wt add T1)"
check "wt add again after a crash"     '[ "$wt_again" = "$wt" ] && [ -d "$wt" ]'
bash "$RUN" own T1 '["src/**","tests/**"]'
check "ownership recorded"             'idleflow_rt get .claude/runs/active/ownership.json tasks.T1.owns | grep -q "src/\*\*"'

echo "--- guard"
wtn="$(native "$wt")"; dn="$(native "$d")"
check "blocks unowned file (native path)" '[ "$(guard_rc "$wtn/other.txt" "$wtn")" = "2" ]'
check "blocks unowned file (posix path)"  '[ "$(guard_rc "$wt/other.txt" "$wt")" = "2" ]'
check "allows owned file"                 '[ "$(guard_rc "$wtn/src/new.txt" "$wtn")" = "0" ]'
check "allows owned nested file"          '[ "$(guard_rc "$wtn/tests/a/b/c.txt" "$wtn")" = "0" ]'
check "allows .claude-run report"         '[ "$(guard_rc "$wtn/.claude-run/report.md" "$wtn")" = "0" ]'
check "blocks worktree marker rewrite"    '[ "$(guard_rc "$wtn/.claude-run/repo" "$wtn")" = "2" ]'
check "blocks ownership.json via editor"  '[ "$(guard_rc "$dn/.claude/runs/active/ownership.json" "$wtn")" = "2" ]'
check "blocks run.json via editor"        '[ "$(guard_rc "$dn/.claude/runs/active/run.json" "$dn")" = "2" ]'
check "blocks run state in parked runs"   '[ "$(guard_rc "$dn/.claude/runs/$id0/run.json" "$dn")" = "2" ]'
check "blocks main checkout code while building" '[ "$(guard_rc "$dn/src/a.txt" "$dn")" = "2" ]'
check "allows main checkout plan.md while building" '[ "$(guard_rc "$dn/.claude/runs/active/plan.md" "$dn")" = "0" ]'
check "allows root progress.md while building"      '[ "$(guard_rc "$dn/progress.md" "$dn")" = "0" ]'
check "allows docs/ while building"                 '[ "$(guard_rc "$dn/docs/research/x.md" "$dn")" = "0" ]'
bash "$RUN" set tasks.T1.status '"approved"'
check "allows main checkout when not building"      '[ "$(guard_rc "$dn/src/a.txt" "$dn")" = "0" ]'
bash "$RUN" set tasks.T1.status '"building"'
check "allows outside any repo"           '[ "$(guard_rc "/nowhere/x.txt" "/nowhere")" = "0" ]'
check "allows on garbage payload"         '[ "$(echo "not json" | bash "$GUARD" 2>/dev/null; echo $?)" = "0" ]'
check "no-runtime still allows"           '[ "$(printf "{}" | IDLEFLOW_RUNTIME=/no/such/bin bash "$GUARD" 2>/dev/null; echo $?)" = "0" ]'
# a worktree whose path has a non-ASCII character must still be guarded (Windows + Python used to fail open)
wtu="$(bash "$RUN" wt add "Té")"; bash "$RUN" own "Té" '["src/**"]'
check "blocks in a non-ASCII worktree"    '[ "$(guard_rc "$(native "$wtu")/é.txt" "$(native "$wtu")")" = "2" ]'
check "allows owned in non-ASCII worktree" '[ "$(guard_rc "$(native "$wtu")/src/é.txt" "$(native "$wtu")")" = "0" ]'
bash "$RUN" wt rm "Té"

echo "--- report / gate"
check "report fails when none written"  '! bash "$RUN" report T1 2>/dev/null'
( cd "$wt" && printf 'x\ny\nz\n' > src/code.py && printf '%s\n' $(seq 1 50) > README.md && printf 'task: T1\nstatus: done\n' > .claude-run/report.md )
r="$(bash "$RUN" report T1)"
check "report copied into run dir"     '[ -f .claude/runs/active/tasks/T1/report.md ] && grep -q "status: done" "$r"'
g="$(bash "$RUN" gate T1)"
check "gate verdict ok"                'echo "$g" | grep -q "\"verdict\":\"ok\""'
check "gate counts code lines (3)"     'echo "$g" | grep -q "\"total\":3,"'
check "gate excludes .md (50+1)"       'echo "$g" | grep -q "\"excluded_total\":51"'
check "gate.json written"              '[ -f .claude/runs/active/tasks/T1/gate.json ]'
( cd "$wt" && seq 1 40 > src/big.py )
check "gate limit override -> audit"   'bash "$RUN" gate T1 10 | grep -q "\"verdict\":\"audit\""'
check "gate verdict split past slack"  'bash "$HERE/diff-gate.sh" "$wt" "$(git rev-parse HEAD)" 10 5 | grep -q "\"verdict\":\"split\""'
check "gate with no exclude list"      'IDLEFLOW_CONF=/nonexistent bash "$HERE/diff-gate.sh" "$wt" "$(git rev-parse HEAD)" | grep -q "\"excluded_total\":0"'
check "gate rejects a bad base"        '! bash "$HERE/diff-gate.sh" "$wt" deadbeef >/dev/null 2>&1'
bash "$RUN" set tasks.T1.base_sha null
check "gate falls back to run base on null" 'bash "$RUN" gate T1 | grep -q "\"verdict\":\"ok\""'
bash "$RUN" set tasks.T1.base_sha '"deadbeef"'
check "run.sh gate fails loudly on a bad base" '! bash "$RUN" gate T1 2>"$scratch/gate.err" && grep -q "bad base" "$scratch/gate.err"'
bash "$RUN" set tasks.T1.base_sha "\"$(git rev-parse HEAD)\""

echo "--- merge, then a second group gates against its own base"
check "merge refuses an unapproved task" 'bash "$RUN" merge T1 >/dev/null 2>&1; [ $? -eq 4 ]'
bash "$RUN" set tasks.T1.status '"approved"'
mkdir -p "$wt/.pytest_cache" && echo v > "$wt/.pytest_cache/v"
m="$(bash "$RUN" merge T1)"
check "merge reports merged"           '[ "$m" = "merged T1" ]'
check "merged file on main"            '[ -f src/code.py ]'
check "merge leaves untracked caches out" '[ ! -e .pytest_cache ] && ! git ls-files | grep -q pytest_cache'
check "merge keeps the human identity" '[ "$(git log -1 --format=%an)" = "Human" ]'
bash "$RUN" set tasks.NOPE.status '"approved"'
check "merge of unknown branch exits 4" 'bash "$RUN" merge NOPE >/dev/null 2>&1; [ $? -eq 4 ]'
check "guard blocks .claude/settings.json while building" 'bash "$RUN" set tasks.T2.status "\"building\""; r=$(guard_rc "$dn/.claude/settings.json" "$dn"); bash "$RUN" set tasks.T2.status "\"approved\""; [ "$r" = "2" ]'
check "guard allows gaps.md while building"              'bash "$RUN" set tasks.T2.status "\"building\""; r=$(guard_rc "$dn/.claude/runs/active/gaps.md" "$dn"); bash "$RUN" set tasks.T2.status "\"approved\""; [ "$r" = "0" ]'
printf 'docs/\n' >> .git/info/exclude; mkdir -p docs; echo n > docs/new.md
check "snapshot skips a docs/ ignored only in info/exclude" 'bash "$RUN" snapshot >/dev/null 2>&1; ! git ls-files --error-unmatch docs/new.md >/dev/null 2>&1'
rm -f docs/new.md; grep -vxF 'docs/' .git/info/exclude > "$scratch/exclude"; cp "$scratch/exclude" .git/info/exclude
echo "docs/" >> .gitignore; git add .gitignore; commit -m "ignore docs"; mkdir -p docs; echo n > docs/new.md
check "snapshot skips an ignored docs/ and says so" 'bash "$RUN" snapshot 2>&1 >/dev/null | grep -q "docs is ignored" && ! git ls-files --error-unmatch docs/new.md >/dev/null 2>&1'
rm -f docs/new.md; sed -i '/^docs\/$/d' .gitignore; git add .gitignore; commit -m "unignore docs"
wt2="$(bash "$RUN" wt add T2 HEAD)"
bash "$RUN" own T2 '["src/**"]'
bash "$RUN" set tasks.T2.status '"approved"'
( cd "$wt2" && printf '1\n2\n3\n4\n5\n' > src/second.py )
g2="$(bash "$RUN" gate T2)"
check "T2 gate sees only T2 lines (5)" 'echo "$g2" | grep -q "\"total\":5,"'
check "merge conflict exits 3"         '( cd "$wt2" && printf "changed\n" > src/code.py ); printf "other\n" > src/code.py; git add -A; commit -m main-change; bash "$RUN" merge T2 >/dev/null 2>&1; [ $? -eq 3 ]'
check "conflict left no MERGE_HEAD"    '[ ! -f .git/MERGE_HEAD ]'

echo "--- finish, then worktrees can still be removed"
f="$(bash "$RUN" finish done)"
check "finish message"                 'echo "$f" | grep -q "finished: done"'
check "active renamed to id"           '[ ! -e .claude/runs/active ] && [ -f ".claude/runs/$id/run.json" ]'
check "log.jsonl appended, compact"    'grep -q "\"id\":\"$id\"" .claude/runs/log.jsonl'
check "status in run.json"             '[ "$(idleflow_rt get ".claude/runs/$id/run.json" status)" = "done" ]'
check "wt list works without a run"    'bash "$RUN" wt list | grep -q "idleflow/$id/T2"'
bash "$RUN" wt rm T1; bash "$RUN" wt rm T2
check "wt rm works without a run"      '[ ! -d "$wt" ] && [ ! -d "$wt2" ]'

echo "--- leftover run is parked by next new"
id2="$(bash "$RUN" new second 2>/dev/null)"
id3="$(bash "$RUN" new third 2>/dev/null)"
check "second run parked"              '[ -f ".claude/runs/$id2/run.json" ] && [ "$(idleflow_rt get ".claude/runs/$id2/run.json" status)" = "abandoned" ]'
check "third run active"               '[ "$(bash "$RUN" get id)" = "$id3" ]'
bash "$RUN" finish test >/dev/null

echo "--- runtime given as a full path"
case "$(idleflow_rt_name)" in
  node*)   full="$(command -v node)";;
  *)       full="$(command -v python3 2>/dev/null || command -v python)";;
esac
check "full-path runtime works"        '[ "$(IDLEFLOW_RUNTIME="$full" idleflow_rt get ".claude/runs/$id/run.json" status)" = "done" ]'
if command -v cygpath >/dev/null 2>&1; then
  fullw="$(cygpath -w "$full")"
  check "backslash runtime path works"  '[ "$(IDLEFLOW_RUNTIME="$fullw" idleflow_rt get ".claude/runs/$id/run.json" status)" = "done" ]'
fi

echo "--- snapshot refuses to run inside a merge"
git checkout -q -b side && echo s > side.txt && git add side.txt && commit -m side && git checkout -q -
echo m > side.txt && git add side.txt && commit -m main-side
git merge -q side >/dev/null 2>&1 || true
check "snapshot refuses during a merge" '[ -f .git/MERGE_HEAD ] && ! bash "$RUN" snapshot 2>/dev/null'
git merge --abort 2>/dev/null || true

echo "--- loc / conf"
check "loc counts code lines only"     '[ "$(bash "$RUN" loc)" = "$(cat src/big.py src/code.py .gitignore | wc -l | tr -d " ")" ]'
check "conf prints runtime"            'bash "$RUN" conf | grep -q "^RUNTIME="'

echo "--- prompt contracts"
researcher="$HERE/../agents/stack-researcher.md"
advisor="$HERE/../agents/stack-advisor.md"
setup="$HERE/../procedures/repo-setup.md"
check "researcher has no total budget"  '! grep -q "tool calls total" "$researcher" && grep -q "official documentation for every unit before" "$researcher"'
check "researcher reply counts unverified" 'grep -q "<K> unverified" "$researcher"'
check "scan reply names research_units" 'grep -q "\"research_units\"" "$advisor" && ! grep -q "\"candidates\"" "$advisor" && grep -q "research_units" "$setup"'
classifier="$HERE/../agents/classifier.md"
feature="$HERE/../commands/feature.md"
fix="$HERE/../commands/fix.md"
init="$HERE/../commands/init.md"
conventions="$HERE/../templates/conventions.md"
check "classifier reports risk and new dependency" 'grep -q "\"risk\"" "$classifier" && grep -q "\"new_dependency\"" "$classifier"'
check "setup research follows new_dependency, not size" '! grep -q "size M/L" "$setup" && grep -q "new_dependency" "$setup" && grep -q "new_dependency" "$feature"'
check "debate runs on size L or high risk" 'grep -q "^## 4\. Debate.*risk" "$feature"'
check "fix sizing ignores module count"   '! grep -q "more than one module" "$fix"'
check "ignore rules go through run.sh ignore" 'grep -q "^ignore_in: unset" "$conventions" && grep -q "\"\$RUN\" ignore" "$setup" && grep -q "\"\$RUN\" ignore" "$init"'
check "R3 chunks and concatenates"      'grep -q "stack-research-<n>.md" "$setup" && grep -q "\`cat\` them in order into \`.claude/runs/active/stack-research.md\` before step 3" "$setup"'

echo
if [ "$fails" -eq 0 ]; then echo "PASS ($(idleflow_rt_name))"; else echo "FAIL: $fails check(s)"; exit 1; fi
