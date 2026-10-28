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
# non-ASCII worktree, main checkout during build, paths through a symlink), report,
# gate (ok / audit / split, excludes, empty DIFF_EXCLUDE, bad base, per-task base after
# an earlier merge),
# get / set / inc (parity cases), the plugin version check, merge (conflict → 3, unknown branch → 4), wt rm after
# finish, finish, a runtime given as a full path, a second `new` that parks a
# leftover run, ignore (info/exclude until conventions say gitignore, no duplicates),
# path, migrate from the .claude/ layout, doctor, team (note names, union merges, team-install), customize, and prompt contracts (the stack scan, researcher and R3 agree on research units,
# budget and reply counts; setup steps follow the classifier's risk and dependency
# fields; ignore rules go through run.sh ignore; the `repo` readability mode is
# offered and enforced). Exit 0 and a final "PASS" line mean everything worked.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$HERE/run.sh"
GUARD="$HERE/ownership-guard.sh"
# shellcheck source=/dev/null
source "$HERE/rt.sh"

fails=0
export IDLEFLOW_NO_UPDATE_CHECK=1   # no network in the selftest
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
cleanup() { cd / ; rm -rf "$d" "${d}__wt" "$d.link" "${d}__wt.link" "$d-mig" 2>/dev/null || true; }
trap cleanup EXIT

echo "--- new on a repo with no commits (what /idleflow:init does)"
cd "$d" && git init -q && git config user.name "Human" && git config user.email "human@example.com"
id0="$(bash "$RUN" new 'fix "quoted" thing' 2>/dev/null)"
check "new works on an unborn branch"     '[ -n "$id0" ] && [ -f .idleflow/runs/active/run.json ]'
check "slug with quotes is valid JSON"    '[ "$(bash "$RUN" get slug)" = "fix-quoted-thing" ]'
check "base_sha empty before first commit" '[ "$(bash "$RUN" get base_sha)" = "" ]'
check "wt add refuses without a commit"   '! bash "$RUN" wt add T0 2>/dev/null'
check "gate refuses without a base"       '! bash "$RUN" gate T0 2>/dev/null'
check "new ignores runs/ locally until asked" 'grep -qxF ".idleflow/runs/" .git/info/exclude && [ ! -e .gitignore ]'
check "ignore defaults to info/exclude"   'bash "$RUN" ignore "scratch-a/" >/dev/null && bash "$RUN" ignore "scratch-a/" >/dev/null && [ "$(grep -cxF "scratch-a/" .git/info/exclude)" = "1" ] && [ ! -e .gitignore ]'
printf '# proj\n' > README.md; mkdir -p .idleflow docs/research; printf 'mode: balanced\n' > .idleflow/conventions.md; printf 'r\n' > docs/research/x.md
printf 'docs/\n' > .gitignore
printf 'unrelated\n' > unrelated.txt; git add unrelated.txt
s="$(bash "$RUN" snapshot)"
check "snapshot commits on unborn branch" 'echo "$s" | grep -q "committed" && git log --oneline | grep -q "project conventions"'
check "snapshot skips gitignored docs/"   '! git ls-files --error-unmatch docs/research/x.md >/dev/null 2>&1'
check "snapshot leaves other staged work" 'git diff --cached --name-only | grep -qx "unrelated.txt"'
check "snapshot keeps the human identity" '[ "$(git log -1 --format=%an)" = "Human" ]'
check "snapshot is a no-op when clean"    '[ "$(bash "$RUN" snapshot)" = "snapshot: nothing to commit" ]'
git reset -q unrelated.txt; rm -f unrelated.txt; printf '.idleflow/runs/\n' > .gitignore; git add .gitignore; commit -m gitignore
bash "$RUN" finish setup >/dev/null

printf 'ignore_in: gitignore\nshared_files: CHANGELOG.md\n' >> .idleflow/conventions.md
mkdir -p src && echo 'a' > src/a.txt && git add . && commit -m base

printf 'node_modules/' > .gitignore   # no trailing newline on purpose
echo "--- new / get / set / inc"
id="$(bash "$RUN" new "self test" 2>/dev/null)"
check ".gitignore newline repaired"    '[ "$(wc -l < .gitignore | tr -d " ")" = "2" ] && grep -qx "node_modules/" .gitignore'
check "new prints an id"               '[ -n "$id" ]'
check "active/run.json exists"         '[ -f .idleflow/runs/active/run.json ]'
check ".gitignore has runs/ when ignore_in: gitignore" 'grep -qx ".idleflow/runs/" .gitignore'
check "ignore follows ignore_in: gitignore" 'bash "$RUN" ignore "scratch-b/" >/dev/null && bash "$RUN" ignore "scratch-b/" >/dev/null && [ "$(grep -cxF "scratch-b/" .gitignore)" = "1" ] && ! grep -qxF "scratch-b/" .git/info/exclude'
check "new records who started the run"  '[ "$(bash "$RUN" get by)" = "Human" ]'
check "new records the plugin version"  '[ "$(bash "$RUN" get plugin_version)" = "$(idleflow_rt get "$HERE/../.claude-plugin/plugin.json" version)" ]'
check "same version, no warning"       '[ -z "$(bash "$RUN" get id 2>&1 >/dev/null)" ]'
v="$(bash "$RUN" get plugin_version)"; bash "$RUN" set plugin_version '"0.0.0"' 2>/dev/null
check "other version warns on stderr"  'bash "$RUN" get id 2>&1 >/dev/null | grep -q "started on idleflow 0.0.0"'
bash "$RUN" set plugin_version "\"$v\"" 2>/dev/null
bash "$RUN" set size '"M"'
check "get/set size"                   '[ "$(bash "$RUN" get size)" = "M" ]'
bash "$RUN" set tasks.T1.status '"building"'
check "set nested key"                 '[ "$(bash "$RUN" get tasks.T1.status)" = "building" ]'
check "get non-string is compact JSON" '[ "$(bash "$RUN" get tasks)" = "{\"T1\":{\"status\":\"building\"}}" ]'
check "inc retries -> 1"               '[ "$(bash "$RUN" inc retries)" = "1" ]'
check "inc a task's retries from unset" '[ "$(bash "$RUN" inc tasks.T1.retries)" = "1" ] && [ "$(bash "$RUN" get tasks.T1.status)" = "building" ]'
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
scratch="$d/.idleflow/runs"   # gitignored, so scratch files never become tracked
cp .idleflow/runs/active/run.json "$scratch/run.bak"; bash "$RUN" set id '""'
check "finish refuses an empty id"     '! bash "$RUN" finish x 2>/dev/null && [ -d .idleflow/runs/active ]'
cp "$scratch/run.bak" .idleflow/runs/active/run.json
check "run.json has no CRLF"           '! grep -q $'"'"'\r'"'"' .idleflow/runs/active/run.json'

echo "--- worktree / ownership"
wt="$(bash "$RUN" wt add T1)"
check "wt add prints path"             '[ -n "$wt" ] && [ -d "$wt" ]'
check "wt on task branch"              'git -C "$wt" rev-parse --abbrev-ref HEAD | grep -q "^idleflow/$id/T1$"'
check "wt marker written"              '[ "$(cat "$wt/.idleflow-run/task-id")" = "T1" ]'
check "wt add stamps the task's start"     '[[ "$(bash "$RUN" get tasks.T1.t_start)" =~ ^[0-9]{10}$ ]]'
check "task base_sha recorded"         '[ "$(bash "$RUN" get tasks.T1.base_sha)" = "$(git rev-parse HEAD)" ]'
wt_again="$(bash "$RUN" wt add T1)"
check "wt add again after a crash"     '[ "$wt_again" = "$wt" ] && [ -d "$wt" ]'
bash "$RUN" own T1 '["src/**","tests/**"]'
check "ownership recorded"             'idleflow_rt get .idleflow/runs/active/ownership.json tasks.T1.owns | grep -q "src/\*\*"'

echo "--- guard"
wtn="$(native "$wt")"; dn="$(native "$d")"
check "blocks unowned file (native path)" '[ "$(guard_rc "$wtn/other.txt" "$wtn")" = "2" ]'
check "blocks unowned file (posix path)"  '[ "$(guard_rc "$wt/other.txt" "$wt")" = "2" ]'
check "allows owned file"                 '[ "$(guard_rc "$wtn/src/new.txt" "$wtn")" = "0" ]'
check "allows owned nested file"          '[ "$(guard_rc "$wtn/tests/a/b/c.txt" "$wtn")" = "0" ]'
check "allows a shared file to any task"  '[ "$(guard_rc "$wtn/CHANGELOG.md" "$wtn")" = "0" ]'
check "allows .idleflow-run/result.md"     '[ "$(guard_rc "$wtn/.idleflow-run/result.md" "$wtn")" = "0" ]'
check "blocks worktree marker rewrite"    '[ "$(guard_rc "$wtn/.idleflow-run/repo" "$wtn")" = "2" ]'
check "blocks ownership.json via editor"  '[ "$(guard_rc "$dn/.idleflow/runs/active/ownership.json" "$wtn")" = "2" ]'
check "blocks run.json via editor"        '[ "$(guard_rc "$dn/.idleflow/runs/active/run.json" "$dn")" = "2" ]'
check "blocks run state in parked runs"   '[ "$(guard_rc "$dn/.idleflow/runs/$id0/run.json" "$dn")" = "2" ]'
check "blocks main checkout code while building" '[ "$(guard_rc "$dn/src/a.txt" "$dn")" = "2" ]'
# the same checkout reached through a symlinked path must not slip past the guard
ln -s "$d" "$d.link"; ln -s "${d}__wt" "${d}__wt.link"
check "blocks main checkout via a symlink"  '[ "$(guard_rc "$d.link/src/a.txt" "$d.link")" = "2" ]'
check "blocks unowned file via a symlink"   '[ "$(guard_rc "${d}__wt.link/T1/other.txt" "${d}__wt.link/T1")" = "2" ]'
check "allows owned file via a symlink"     '[ "$(guard_rc "${d}__wt.link/T1/src/new.txt" "${d}__wt.link/T1")" = "0" ]'
check "allows main checkout plan.md while building" '[ "$(guard_rc "$dn/.idleflow/runs/active/plan.md" "$dn")" = "0" ]'
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
( cd "$wt" && printf 'x\ny\nz\n' > src/code.py && printf '%s\n' $(seq 1 50) > README.md && printf 'task: T1\nstatus: done\n' > .idleflow-run/result.md )
r="$(bash "$RUN" report T1)"
check "report copied into run dir"     '[ -f .idleflow/runs/active/tasks/T1/report.md ] && grep -q "status: done" "$r"'
touch -t 200001010000 "$wt/.idleflow-run/result.md"; echo "edited: yes" >> "$r"
g="$(bash "$RUN" gate T1)"
check "gate keeps a newer run copy"    'grep -q "edited: yes" "$r"'
printf 'task: T1\nstatus: partial\n' > "$wt/.idleflow-run/result.md"; touch -t 203001010000 "$wt/.idleflow-run/result.md"
bash "$RUN" gate T1 >/dev/null
check "gate refreshes after a rewrite" 'grep -q "status: partial" "$r" && ! grep -q "edited: yes" "$r"'
check "gate verdict ok"                'echo "$g" | grep -q "\"verdict\":\"ok\""'
check "gate counts code lines (3)"     'echo "$g" | grep -q "\"total\":3,"'
check "gate excludes .md (50+1)"       'echo "$g" | grep -q "\"excluded_total\":51"'
check "gate.json written"              '[ -f .idleflow/runs/active/tasks/T1/gate.json ]'
( cd "$wt" && seq 1 40 > src/big.py )
check "gate limit override -> audit"   'bash "$RUN" gate T1 10 | grep -q "\"verdict\":\"audit\""'
( cd "$wt" && mkdir -p .idleflow && printf 'DIFF_LIMIT=100000\n' > .idleflow/idleflow.conf )
g2="$(bash "$HERE/diff-gate.sh" "$wt" "$(git rev-parse HEAD)" 2>/dev/null)"
check "gate ignores settings the task wrote"  'echo "$g2" | grep -q "\"limit\":1500"'
rm -rf "$wt/.idleflow"
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
check "merge stamps the task's merge"     '[[ "$(bash "$RUN" get tasks.T1.t_merge 2>/dev/null)" =~ ^[0-9]{10}$ ]]'
check "merge reports merged"           '[ "$m" = "merged T1" ]'
check "merged file on main"            '[ -f src/code.py ]'
check "merge leaves untracked caches out" '[ ! -e .pytest_cache ] && ! git ls-files | grep -q pytest_cache'
check "merge keeps the human identity" '[ "$(git log -1 --format=%an)" = "Human" ]'
bash "$RUN" set tasks.NOPE.status '"approved"'
check "merge of unknown branch exits 4" 'bash "$RUN" merge NOPE >/dev/null 2>&1; [ $? -eq 4 ]'
check "guard blocks .claude/settings.json while building" 'bash "$RUN" set tasks.T2.status "\"building\""; r=$(guard_rc "$dn/.claude/settings.json" "$dn"); bash "$RUN" set tasks.T2.status "\"approved\""; [ "$r" = "2" ]'
check "guard allows gaps.md while building"              'bash "$RUN" set tasks.T2.status "\"building\""; r=$(guard_rc "$dn/.idleflow/runs/active/gaps.md" "$dn"); bash "$RUN" set tasks.T2.status "\"approved\""; [ "$r" = "0" ]'
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
check "active renamed to id"           '[ ! -e .idleflow/runs/active ] && [ -f ".idleflow/runs/$id/run.json" ]'
check "log.jsonl appended, compact"    'grep -q "\"id\":\"$id\"" .idleflow/runs/log.jsonl'
check "status in run.json"             '[ "$(idleflow_rt get ".idleflow/runs/$id/run.json" status)" = "done" ]'
check "wt list works without a run"    'bash "$RUN" wt list | grep -q "idleflow/$id/T2"'
bash "$RUN" wt rm T1; bash "$RUN" wt rm T2
check "wt rm works without a run"      '[ ! -d "$wt" ] && [ ! -d "$wt2" ]'

echo "--- leftover run is parked by next new"
id2="$(bash "$RUN" new second 2>/dev/null)"
id3="$(bash "$RUN" new third 2>/dev/null)"
check "second run parked"              '[ -f ".idleflow/runs/$id2/run.json" ] && [ "$(idleflow_rt get ".idleflow/runs/$id2/run.json" status)" = "abandoned" ]'
check "third run active"               '[ "$(bash "$RUN" get id)" = "$id3" ]'
bash "$RUN" finish test >/dev/null

echo "--- runtime given as a full path"
case "$(idleflow_rt_name)" in
  node*)   full="$(command -v node)";;
  *)       full="$(command -v python3 2>/dev/null || command -v python)";;
esac
check "full-path runtime works"        '[ "$(IDLEFLOW_RUNTIME="$full" idleflow_rt get ".idleflow/runs/$id/run.json" status)" = "done" ]'
if command -v cygpath >/dev/null 2>&1; then
  fullw="$(cygpath -w "$full")"
  check "backslash runtime path works"  '[ "$(IDLEFLOW_RUNTIME="$fullw" idleflow_rt get ".idleflow/runs/$id/run.json" status)" = "done" ]'
fi

echo "--- snapshot refuses to run inside a merge"
git checkout -q -b side && echo s > side.txt && git add side.txt && commit -m side && git checkout -q -
echo m > side.txt && git add side.txt && commit -m main-side
git merge -q side >/dev/null 2>&1 || true
check "snapshot refuses during a merge" '[ -f .git/MERGE_HEAD ] && ! bash "$RUN" snapshot 2>/dev/null'
git merge --abort 2>/dev/null || true

echo "--- loc / conf"
check "loc counts code lines only"     '[ "$(bash "$RUN" loc)" = "$(cat src/big.py src/code.py .gitignore $(git ls-files .gitattributes) | wc -l | tr -d " ")" ]'
c="$(bash "$RUN" conf)"
check "conf prints runtime"            'echo "$c" | grep -q "^RUNTIME="'
check "conf prints plugin version"     'echo "$c" | grep -q "^PLUGIN_VERSION=[0-9]"'

echo "--- path / migrate from the .claude/ layout"
check "lessons live in .idleflow by default" '[ "$(bash "$RUN" path lessons)" = "$(native "$(git rev-parse --show-toplevel)")/.idleflow/lessons.md" ]'
printf 'lessons_in: docs\n' >> .idleflow/conventions.md
check "lessons_in: docs moves them"      '[ "$(bash "$RUN" path lessons)" = "$(native "$(git rev-parse --show-toplevel)")/docs/lessons.md" ]'
m="$d-mig"; mkdir -p "$m" && cd "$m" && git init -q && git config user.name "Human" && git config user.email "human@example.com"
mkdir -p .claude/runs/20260101-x && printf 'mode: repo\n' > .claude/conventions.md && printf '# Lessons\n' > .claude/lessons.md
printf '{}' > .claude/settings.json && printf 'Read `.claude/lessons.md` first.\n' > CLAUDE.md && mkdir -p docs/notes && printf 'see .claude/runs/log.jsonl\n' > docs/notes/x.md && printf '.claude/runs/\n' > .gitignore
printf '{"id":"x"}\n' > .claude/runs/log.jsonl && printf '.claude-run/\n' >> .git/info/exclude
git add -A && commit -m old
doc="$(bash "$RUN" doctor)"
check "doctor flags the old layout"       'echo "$doc" | grep -q "^fail layout: .*\.claude/lessons\.md.*fix: run.sh migrate"'
mkdir -p .claude/runs/active
check "migrate refuses an active old run" '! bash "$RUN" migrate 2>/dev/null && [ -f .claude/lessons.md ]'
rmdir .claude/runs/active
out="$(bash "$RUN" migrate)"
check "migrate moves conventions and lessons" '[ -f .idleflow/conventions.md ] && [ -f .idleflow/lessons.md ] && [ ! -e .claude/lessons.md ]'
check "migrate keeps past runs"           '[ -f .idleflow/runs/log.jsonl ] && [ -d .idleflow/runs/20260101-x ] && [ ! -e .claude/runs ]'
check "migrate leaves Claude Code files"  '[ -f .claude/settings.json ]'
check "migrate rewrites old paths"        'grep -qF ".idleflow/runs/log.jsonl" docs/notes/x.md && grep -qF ".idleflow/lessons.md" CLAUDE.md && grep -qx ".idleflow/runs/" .gitignore && grep -qx ".idleflow-run/" .git/info/exclude'
check "migrate commits once, cleanly"     'echo "$out" | grep -q "committed" && [ "$(git log -1 --format=%s)" = "chore: move idleflow files to .idleflow/" ] && [ -z "$(git status --porcelain)" ]'
doc="$(bash "$RUN" doctor)"
check "doctor passes the new layout"      'echo "$doc" | grep -q "^ok layout" && echo "$doc" | grep -q "^ok shared: .idleflow/lessons.md is committed"'
check "doctor names unanswered settings"  'echo "$doc" | grep -q "^warn conventions: not answered yet: ignore_in docs"'
check "update-check is silent offline"    '[ -z "$(bash "$RUN" update-check)" ]'
check "migrate again is a no-op"          '[ "$(bash "$RUN" migrate)" = "migrate: nothing to move" ]'

echo "--- records where the repo keeps them"
cp .idleflow/conventions.md "$d-conv.bak"
printf 'lessons_in: lessons.md\nprogress_file: docs/progress.md\nindex_file: docs/index.md\nsessions_dir: docs/notes\nsession_names: numbered\n' >> .idleflow/conventions.md
top="$(native "$(git rev-parse --show-toplevel)")"
check "record paths follow the conventions" '[ "$(bash "$RUN" path lessons)" = "$top/lessons.md" ] && [ "$(bash "$RUN" path progress)" = "$top/docs/progress.md" ] && [ "$(bash "$RUN" path index)" = "$top/docs/index.md" ]'
mkdir -p docs/notes && touch docs/notes/s_0003.md docs/notes/s_0010.md
check "numbered notes continue the repo's count" '[ "$(bash "$RUN" session-name)" = "docs/notes/s_0011.md" ]'
rm -rf docs
sed -i.bak 's#^progress_file: .*#progress_file: ../outside.md#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
check "a path outside the repo falls back"  'p="$(bash "$RUN" path progress 2>/dev/null)"; [ "$p" = "$top/progress.md" ] && bash "$RUN" path progress 2>&1 >/dev/null | grep -q "not a relative path"'
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"

echo "--- worktrees inside the repo, with an approved setup command"
cp .idleflow/conventions.md "$d-conv.bak"
mkdir -p shared-big src && echo data > shared-big/f && echo x > src/keep.py && git add src/keep.py && commit -q -m "add src"
printf 'worktrees_in: inside\nworktree_setup: ln -s "$MAIN/shared-big" shared-big && touch .setup-ran\n' >> .idleflow/conventions.md
git add .idleflow/conventions.md && commit -q -m "setup command"
bash "$RUN" new unapproved >/dev/null 2>&1
out="$(bash "$RUN" wt add T5 2>&1)"; rc=$?
check "an unapproved setup command never runs (exit 7)" '[ "$rc" = 7 ] && echo "$out" | grep -q "not approved" && [ ! -e .idleflow/worktrees/T5/.setup-ran ]'
check "commands lists it as unapproved" 'bash "$RUN" commands | grep -q "^unapproved worktree_setup: ln -s"'
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor warns about an unapproved command" 'echo "$doc" | grep -q "^warn commands: not approved by you yet.*fix: read the command, then run.sh approve worktree_setup$"'
bash "$RUN" wt rm T5; bash "$RUN" finish done >/dev/null
bash "$RUN" approve worktree_setup >/dev/null
check "approval is local, never committed" '[ -n "$(git config --local idleflow.approved-worktree-setup)" ] && [ -z "$(git status --porcelain .idleflow)" ]'
printf 'worktree_setup: touch "$MAIN/pwned"\n' > "$scratch/edit" && sed -i.bak "s#^worktree_setup: .*#$(cat "$scratch/edit" | sed 's/[&#]/\\&/g')#" .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
bash "$RUN" new inside >/dev/null 2>&1
wi="$(bash "$RUN" wt add T9 2>/dev/null)"; wi_rc=$?
check "a working-tree edit to the command changes nothing" '[ "$wi_rc" = 0 ] && [ ! -e pwned ] && [ -f "$wi/.setup-ran" ]'
git checkout -q -- .idleflow/conventions.md
check "an inside worktree lives in .idleflow/worktrees" '[ "$wi" = "$(native "$(git rev-parse --show-toplevel)")/.idleflow/worktrees/T9" ] && [ -d "$wi/src" ]'
check "the setup command ran in the worktree" '[ -f "$wi/shared-big/f" ]'
bash "$RUN" own T9 '["src/**"]' >/dev/null; bash "$RUN" set tasks.T9.status '"building"'
check "guard: an owned file in an inside worktree is allowed" '[ "$(guard_rc "$wi/src/keep.py" "$wi")" = "0" ]'
check "guard: an unowned file in an inside worktree is blocked" '[ "$(guard_rc "$wi/other.py" "$wi")" = "2" ]'
check "guard: the main checkout stays blocked while building" '[ "$(guard_rc "$PWD/src/keep.py" "$PWD")" = "2" ] && [ "$(guard_rc "$PWD/.idleflow/conventions.md" "$PWD")" = "2" ]'
st="$(git status --porcelain --untracked-files=all)"
check "inside worktrees do not dirty the main checkout" '! echo "$st" | grep -q "\.idleflow/worktrees"'
bash "$RUN" set tasks.T9.status '"approved"'; bash "$RUN" wt rm T9; bash "$RUN" finish done >/dev/null
sed -i.bak 's#^worktree_setup: .*#worktree_setup: echo boom; exit 3#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
git add .idleflow/conventions.md && commit -q -m "failing setup"
bash "$RUN" new failing >/dev/null 2>&1
out="$(bash "$RUN" wt add T8 2>&1)"; rc=$?
check "a changed command needs approval again" '[ "$rc" = 7 ]'
bash "$RUN" approve worktree_setup >/dev/null; bash "$RUN" wt rm T8
out="$(bash "$RUN" wt add T8 2>&1)"; rc=$?
check "a failing setup stops wt add (exit 6)" '[ "$rc" = 6 ] && echo "$out" | grep -q "worktree setup failed for T8" && echo "$out" | grep -q boom'
bash "$RUN" wt rm T8; bash "$RUN" finish done >/dev/null
sed -i.bak 's#^worktree_setup: .*#worktree_setup: echo changed >> src/keep.py#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
git add .idleflow/conventions.md && commit -q -m "editing setup"; bash "$RUN" approve worktree_setup >/dev/null
bash "$RUN" new editing >/dev/null 2>&1
out="$(bash "$RUN" wt add T7 2>&1)"; rc=$?
check "a setup that edits tracked files is refused and undone" '[ "$rc" = 6 ] && echo "$out" | grep -q "changed tracked files" && [ "$(cat .idleflow/worktrees/T7/src/keep.py)" = x ]'
bash "$RUN" wt rm T7; bash "$RUN" finish done >/dev/null
rm -rf shared-big; cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"

echo "--- the repo's gate"
git add -u && commit -q -m "tidy before the gate"
cp .idleflow/conventions.md "$d-conv.bak"
printf 'gate: grep -q x src/keep.py && echo gate-ok\n' >> .idleflow/conventions.md
git add .idleflow/conventions.md && commit -q -m "gate"
bash "$RUN" new gated >/dev/null 2>&1
printf 'dirty\n' >> src/keep.py; bash "$RUN" approve gate >/dev/null
check "the base gate refuses a dirty checkout" '! bash "$RUN" repo-gate base >/dev/null 2>&1'
git checkout -q -- src/keep.py; git config --local --unset idleflow.approved-gate
out="$(bash "$RUN" repo-gate base 2>&1)"; rc=$?
check "an unapproved gate never runs (exit 7)" '[ "$rc" = 7 ] && [ ! -e .idleflow/runs/active/repo-gate-base.log ]'
bash "$RUN" approve gate >/dev/null
out="$(bash "$RUN" repo-gate base 2>/dev/null)"; rc=$?
check "the gate runs on the base and keeps its output" '[ "$rc" = 0 ] && echo "$out" | grep -q "^repo gate base: exit 0" && grep -q gate-ok .idleflow/runs/active/repo-gate-base.log'
wg="$(bash "$RUN" wt add T4 2>/dev/null)"; ( cd "$wg" && echo y > src/keep.py )
out="$(bash "$RUN" repo-gate T4 2>/dev/null)"; rc=$?
check "a red gate in a task worktree exits 1" '[ "$rc" = 1 ] && echo "$out" | grep -q "^repo gate T4: exit 1" && [ -f .idleflow/runs/active/tasks/T4/repo-gate.log ]'
bash "$RUN" wt rm T4; bash "$RUN" finish done >/dev/null
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"

echo "--- conventional commits"
cp .idleflow/conventions.md "$d-conv.bak"
printf 'commit_format: conventional\n' >> .idleflow/conventions.md
bash "$RUN" new conventional-commits-with-a-long-slug-name >/dev/null 2>&1
wc6="$(bash "$RUN" wt add T6 2>/dev/null)"
( cd "$wc6" && echo y >> src/keep.py )
bash "$RUN" set tasks.T6.status '"approved"'; bash "$RUN" merge T6 >/dev/null 2>&1
# the merge and its second parent by name: commits made in the same second sort either way in git log
subjects="$(git log -1 --format=%s HEAD; git log -1 --format=%s HEAD^2)"; bodies="$(git log -1 --format=%b HEAD; git log -1 --format=%b HEAD^2)"
cc_re='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([A-Za-z0-9_./-]+\))?!?: [^ ]'
check "merge and finish commits are Conventional Commits" '[ "$(echo "$subjects" | grep -Ec "$cc_re")" = 2 ] && [ "$(echo "$subjects" | awk "length > 72" | wc -l | tr -d " ")" = 0 ]'
check "the run id moves to the commit body" '[ "$(echo "$bodies" | grep -c "^Run: ")" = 2 ]'
bash "$RUN" wt rm T6; bash "$RUN" finish done >/dev/null
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"

echo "--- team"
check "session notes are named by time and author" 'bash "$RUN" session-name | grep -Eq "^docs/sessions/s_[0-9]{8}-[0-9]{4}-human\.md$"'
mkdir -p docs/sessions && touch "$(bash "$RUN" session-name)"
check "a second note in the same minute gets a suffix" 'bash "$RUN" session-name | grep -q -- "-human-2\.md$"'
rm -rf docs
bash "$RUN" snapshot >/dev/null
check "snapshot sets union merges for shared logs" 'grep -qx ".idleflow/lessons.md merge=union" .gitattributes && grep -qx "progress.md merge=union" .gitattributes && git ls-files --error-unmatch .gitattributes >/dev/null 2>&1'
printf '{"permissions":{"allow":["Bash(ls)"]}}' > .claude/settings.json
bash "$RUN" team-install >/dev/null
check "team-install recommends idleflow, keeps the rest" '[ "$(idleflow_rt get .claude/settings.json enabledPlugins.idleflow@idlesync)" = "true" ] && [ "$(idleflow_rt get .claude/settings.json extraKnownMarketplaces.idlesync.source.repo)" = "Idle-Sync/idleflow" ] && grep -q "Bash(ls)" .claude/settings.json'
printf '{bad' > .claude/settings.json
bash "$RUN" team-install >/dev/null
check "team-install adds the CLAUDE.md note once" '[ "$(grep -c "idleflow install start" CLAUDE.md)" = "1" ] && grep -q "claude plugin install idleflow@idlesync" CLAUDE.md && grep -qF ".idleflow/lessons.md" CLAUDE.md'
check "team-install refuses broken JSON"  '! bash "$RUN" team-install 2>/dev/null && [ "$(cat .claude/settings.json)" = "{bad" ]'
printf '{}' > .claude/settings.json
printf '# P\n## Must do (v1)\n- a — done when: b\n## Milestones\n1. one\n' > prd.md; printf '# Progress\n<!-- progress start -->\n' > progress.md
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor finds milestones still in prd.md" 'echo "$doc" | grep -q "^warn milestones: milestones are still in prd.md"'
printf '# P\n## Must do (v1)\n- a — done when: b\n' > prd.md; printf '# Progress\n## Milestones\n### M1: one\n- [ ] a\n## Log\n<!-- progress start -->\n' > progress.md
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor accepts milestones in progress.md" 'echo "$doc" | grep -q "^ok milestones"'
printf '# Progress\n## Milestones\n### M1: one\n- [x] a (run r1)\n- [ ] a\n## Log\n<!-- progress start -->\n' > progress.md
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor finds a milestone item a merge doubled" 'echo "$doc" | grep -q "^warn milestones: listed twice under Milestones (a merge kept both sides): a"'
rm -f prd.md progress.md

echo "--- customize"
bash "$RUN" custom set DIFF_LIMIT 3000 >/dev/null
c="$(bash "$RUN" conf)"
check "a project setting overrides the default" 'echo "$c" | grep -qx "DIFF_LIMIT=3000"'
check "STEP_MUTATION is a setting"         'bash "$RUN" custom set STEP_MUTATION on >/dev/null && bash "$RUN" custom unset STEP_MUTATION >/dev/null'
check "out-of-range values are refused"   '! bash "$RUN" custom set DEBATE_ROUNDS 5 2>/dev/null && ! bash "$RUN" custom set MODEL_NO_SUCH_AGENT opus 2>/dev/null'
printf 'touch "%s/pwned"\nDIFF_SLACK=$(touch "%s/pwned")\n' "$m" "$m" >> .idleflow/idleflow.conf
c="$(bash "$RUN" conf 2>&1)"
mkdir -p src && touch src/x.py
check "catch-all excludes are refused"   '! bash "$RUN" custom set DIFF_EXCLUDE_ADD "**/*" 2>/dev/null && ! bash "$RUN" custom set DIFF_EXCLUDE_ADD "*/*" 2>/dev/null && bash "$RUN" custom set DIFF_EXCLUDE_ADD "**/gen/**" >/dev/null && bash "$RUN" custom unset DIFF_EXCLUDE_ADD >/dev/null'
check "report consent is local, never committed" '[ "$(bash "$RUN" custom report)" = ask ] && bash "$RUN" custom report always >/dev/null && [ "$(git config --local idleflow.reportCustomizations)" = always ] && ! grep -q REPORT .idleflow/idleflow.conf && ! bash "$RUN" custom set REPORT_CUSTOMIZATIONS always 2>/dev/null'
check "the project file is parsed, never run" 'echo "$c" | grep -q "ignored in .idleflow/idleflow.conf" && [ ! -e "$m/pwned" ] && echo "$c" | grep -qx "DIFF_SLACK=300"'
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor lists skipped and kept settings" 'echo "$doc" | grep -q "^warn customizations: lines skipped" && echo "$doc" | grep -q "^ok customizations: DIFF_LIMIT=3000"'
bash "$RUN" custom set MODEL_REVIEW_CONFORM opus >/dev/null; mkdir -p .idleflow/agents; echo "Also check X." > .idleflow/agents/retro.md
a1="$(bash "$RUN" agent review-conform 2>/dev/null)"; a2="$(bash "$RUN" agent retro 2>/dev/null)"
check "agent reports model and instructions" 'echo "$a1" | grep -qx "model: opus" && echo "$a2" | grep -q "^extra: .*\.idleflow/agents/retro\.md"'
bash "$RUN" custom replace planner >/dev/null 2>&1
a1="$(bash "$RUN" agent planner 2>/dev/null)"
check "replace copies the built-in agent"  'grep -q "^name: idleflow-planner" .claude/agents/idleflow-planner.md && echo "$a1" | grep -qx "agent: idleflow-planner"'
sed -i.bak 's/^You are the planner\./You are the planner for this repo./' .claude/agents/idleflow-planner.md && rm -f .claude/agents/idleflow-planner.md.bak
printf 'a line an older idleflow had\n' >> .idleflow/agents/planner.base.md
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor sees the built-in agent changed" 'echo "$doc" | grep -q "^warn agents: the built-in planner changed"'
bash "$RUN" custom merge planner >/dev/null 2>&1
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "merge keeps the project's edits"    'grep -q "planner for this repo" .claude/agents/idleflow-planner.md && echo "$doc" | grep -q "^ok agents: replaced planner is current"'
bash "$RUN" custom restore planner >/dev/null 2>&1
printf -- '- [r1] SIZE_S_MAX: 150 -> 200 because a; evidence: r1\n- [r2] SIZE_S_MAX: 150 -> 250 because b; evidence: r1 r2\n- [r2] MAX_RETRIES: 1 -> 2 because c; evidence: r2\n- [r2] DIFF_LIMIT: 1500 -> 3000 because d; evidence: r2\n' > .idleflow/runs/config-proposals.md
printf -- '- declined: MAX_RETRIES -> 2 (r2, today)\n' > .idleflow/suggestions.md
sug="$(bash "$RUN" doctor 2>/dev/null | grep '^suggest' || true)"
check "doctor offers the newest open suggestion" '[ "$(echo "$sug" | wc -l | tr -d " ")" = "1" ] && echo "$sug" | grep -q "^suggest SIZE_S_MAX: .*150 -> 250.*fix: /idleflow:customize SIZE_S_MAX 250"'
a1="$(bash "$RUN" agent planner 2>/dev/null)"
check "restore brings the built-in back"   '[ ! -e .claude/agents/idleflow-planner.md ] && echo "$a1" | grep -qx "agent: idleflow:planner"'
printf 'x\n' > .claude/conventions.md
check "migrate refuses two copies"        '! bash "$RUN" migrate 2>/dev/null'
cd "$d"

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
check "repo readability mode is offered and enforced" 'grep -q "^| \`repo\` |" "$conventions" && grep -q "Match this repo" "$setup" && grep -q "Match this repo" "$HERE/../commands/style.md" && grep -q "\`repo\`" "$HERE/../agents/implementer.md" && grep -q "\`repo\`" "$HERE/../agents/implementer-hard.md" && grep -q "\`repo\`" "$HERE/../agents/review-conform.md"'
check "R3 chunks and concatenates"      'grep -q "stack-research-<n>.md" "$setup" && grep -q "\`cat\` them in order into \`.idleflow/runs/active/stack-research.md\` before step 3" "$setup"'

echo
if [ "$fails" -eq 0 ]; then echo "PASS ($(idleflow_rt_name))"; else echo "FAIL: $fails check(s)"; exit 1; fi
