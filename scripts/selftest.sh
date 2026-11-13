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

# Every check's test is single-quoted on purpose, so check() expands it when it runs.
# shellcheck disable=SC2016
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
# brackets in a glob are literal: framework routes are named [slug].astro, [...id]/+page.svelte
bash "$RUN" own T1 '["src/**","tests/**","pages/[slug].astro"]'
check "allows a bracketed route file it owns"   '[ "$(guard_rc "$wtn/pages/[slug].astro" "$wtn")" = "0" ]'
check "brackets are not a character class"      '[ "$(guard_rc "$wtn/pages/s.astro" "$wtn")" = "2" ]'
mkdir -p "$wt/pages" && touch "$wt/pages/[slug].astro" "$wt/pages/s.astro" "$wt/other.txt"
git -C "$wt" add pages other.txt && git -C "$wt" -c user.name=t -c user.email=t@t commit -qm "T1: pages"
touch "$wt/setup-output.txt"
check "unowned lists only what the task may not change" '[ "$(bash "$RUN" unowned T1 | paste -sd, -)" = "other.txt,pages/s.astro" ]'
git -C "$wt" reset -q --hard HEAD~1 && rm -f "$wt/setup-output.txt"
bash "$RUN" own T1 '["src/**","tests/**","docs/café.md","src/café.py"]'
mkdir -p "$wt/docs" && echo x > "$wt/docs/café.md" && echo y > "$wt/src/café.py" && ( cd "$wt" && git add docs/café.md src/café.py && commit -m "T1: café" )
check "unowned reads non-ASCII paths as the guard does" '[ -z "$(bash "$RUN" unowned T1)" ]'
check "the gate names non-ASCII files as they are"      'bash "$RUN" gate T1 | grep -q "\"src/café.py\""'
( cd "$wt" && git reset -q --hard HEAD~1 )
hk="$(git rev-parse --git-common-dir)/hooks"; mkdir -p "$hk"; printf '#!/bin/sh\necho "${GIT_CONFIG_PARAMETERS:-}" >> "%s"\n' "$scratch/hook.env" > "$hk/pre-commit"; chmod +x "$hk/pre-commit"; : > "$scratch/hook.env"
echo hooked > hooked.txt; git add hooked.txt; bash "$RUN" snapshot >/dev/null 2>&1; commit -m hooked >/dev/null 2>&1 || true
( cd "$wt" && echo h > src/hook.txt && git add src/hook.txt && bash -c 'source "$0"; git commit -q -m "T1: hook"' "$HERE/conf.sh" )
check "the repo's hooks keep the repo's git settings" '[ -s "$scratch/hook.env" ] && ! grep -q quotePath "$scratch/hook.env"'
rm -f "$hk/pre-commit"; ( cd "$wt" && git reset -q --hard HEAD~1 )
# names git quotes even with quotePath off: a double quote, a backslash, a tab
odd="$(printf 'src/a"b\\c\td.py')"
printf 'x\ny\n' > "$wt/$odd"; ( cd "$wt" && git add -- "$odd" && commit -m "T1: odd name" )
check "unowned reads any file name as it is"      '[ -z "$(bash "$RUN" unowned T1)" ]'
check "the gate names any file as it is"          'bash "$RUN" gate T1 | grep -qF "\"src/a\\\"b\\\\c\\td.py\",2"'
bs="$(printf 'src\\x.py')"; echo z > "$wt/$bs"; ( cd "$wt" && git add -- "$bs" && commit -m "T1: backslash" )
check "a backslash in a name is not a folder"     '[ "$(bash "$RUN" unowned T1)" = "$bs" ]'
( cd "$wt" && git reset -q --hard HEAD~1 )
printf '3\t1\t\0old/x.py\0new/x.py\0' > "$scratch/ns-rename"
check "the gate reads a rename record as the new path" 'idleflow_rt gate 10 5 "$scratch/ns-rename" "$scratch/ns-rename" | grep -qF "\"files\":1," && idleflow_rt gate 10 5 "$scratch/ns-rename" "$scratch/ns-rename" | grep -qF "[[\"new/x.py\",4]]"'
( cd "$wt" && git reset -q --hard HEAD~1 )
check "unowned fails on an unknown task"        '! bash "$RUN" unowned T9 >/dev/null 2>&1'
bash "$RUN" own T1 '["src/**","tests/**"]'
check "allows outside any repo"           '[ "$(guard_rc "/nowhere/x.txt" "/nowhere")" = "0" ]'
check "allows on garbage payload"         '[ "$(echo "not json" | bash "$GUARD" 2>/dev/null; echo $?)" = "0" ]'
check "no-runtime still allows"           '[ "$(printf "{}" | IDLEFLOW_RUNTIME=/no/such/bin bash "$GUARD" 2>/dev/null; echo $?)" = "0" ]'
# a worktree whose path has a non-ASCII character must still be guarded (Windows + Python used to fail open)
wtu="$(bash "$RUN" wt add "Té")"; bash "$RUN" own "Té" '["src/**"]'
check "blocks in a non-ASCII worktree"    '[ "$(guard_rc "$(native "$wtu")/é.txt" "$(native "$wtu")")" = "2" ]'
check "allows owned in non-ASCII worktree" '[ "$(guard_rc "$(native "$wtu")/src/é.txt" "$(native "$wtu")")" = "0" ]'
bash "$RUN" wt rm "Té"
touch "${d}__wt/keep-me"
check "wt add refuses an id that is a path"       '! bash "$RUN" wt add .. 2>/dev/null && ! bash "$RUN" wt add ../x 2>/dev/null && [ -e "${d}__wt/keep-me" ] && [ ! -e "${d}__wt/x" ]'
check "every task-id subcommand refuses a path"   '( for c in "wt rm" own unowned report gate merge exec preview repo-gate; do out="$(bash "$RUN" $c ../T1 x y 2>&1)"; case "$out" in "not a task id: "*) ;; *) exit 1;; esac; done )'
check "an id git or Windows cannot use is refused" '! bash "$RUN" wt add "a~1" 2>/dev/null && ! bash "$RUN" wt add "x.lock" 2>/dev/null && ! bash "$RUN" wt add _gate-base 2>/dev/null && ! bash "$RUN" wt add CON 2>/dev/null'
rm -f "${d}__wt/keep-me"

echo "--- kill guard"
KILLG="$HERE/kill-guard.sh"
kill_rc() { # kill_rc <command> [cwd] [project dir] -> exit code of the hook; the cwd defaults to task T1's worktree
  local j c; j="$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; j="${j//$'\n'/\\n}"
  c="$(native "${2:-$wt}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$c" "$j" | CLAUDE_PROJECT_DIR="${3:-}" bash "$KILLG" 2>/dev/null; echo $?
}
for c in 'pkill -f "docker ps --format"' 'killall node' 'sudo pkill vite' 'ls; pkill -9 x' 'kill $(pgrep -f vite)' 'pgrep -f x | xargs kill' 'fuser -k 4321/tcp' \
         "$(printf 'ls\npkill x')" 'sudo -u root pkill x' 'if true; then pkill x; fi' '/usr/bin/pkill x' 'timeout 5 pkill x' 'nohup pkill x &' \
         "bash -c 'pkill x'" 'kill -9 $(lsof -t -i:4321)' 'for p in $(pgrep vite); do kill $p; done' 'pgrep vite | while read p; do kill "$p"; done' 'xargs -I{} kill {} < pids' \
         "sudo bash -c 'pkill x'" "bash -lc 'pkill x'" "eval 'pkill x'" "watch -n 1 'pkill x'" 'sudo -iu root pkill x' \
         "$(printf 'cat > f <<%sEOF%s\nit%ss done\nEOF\npkill -f vite' "'" "'" "'")" "$(printf 'bash <<EOF\npkill x\nEOF')" \
         'npx kill-port 4321' 'fuser --kill 4321/tcp' 'kill -9 -1' 'pids=$(pgrep x); kill $pids' 'runuser -u me -- pkill x' \
         "find /proc -name '[0-9]*' -exec kill {} ;" '>out pkill x' "$(printf '$(bash -c "%.0s' $(seq 1 12))" \
         'while read p; do kill $p; done < <(pgrep -f vite)' 'pids=($(pgrep vite)); kill ${pids[@]}' \
         "pgrep -f vite | xargs -I{} sh -c 'kill {}'" "trap 'pkill -f vite' EXIT" 'busybox pkill vite' \
         "$(printf 'echo $((1<<2))\npkill x')" 'kill "$PID"; pgrep -f vite || echo stopped' \
         'echo $((echo a); pkill node)' '((true) ; pkill node)' 'kill $(ps -e -p 1 -o pid=)' 'kill $(ps ax -p 1 -o pid=)' \
         'kill $(lsof -p ^1 -t)' 'kill $(lsof -p 1 -i :3000 -t)'; do
  check "refuses a kill by name or pattern: $c" '[ "$(kill_rc "$c")" = 2 ]'
done
for c in 'kill 1234' 'kill -- -4242' 'grep -n pkill agents/*.md' 'echo "never use pkill"' 'pgrep -f vite' \
         "grep 'a;pkill' file" 'echo "x; killall y"' 'git commit -m "refuse pkill and killall"' 'sleep 300 & pid=$!; kill "$pid"' 'echo hi # pkill x' \
         "$(printf 'cat > notes.md <<%sEOF%s\npkill -f vite is forbidden\nEOF' "'" "'")" 'kill "$(cat .run/server.pid)"' \
         'constructor -x y' 'kill -1 1234' 'if ps -p "$PID" >/dev/null; then kill "$PID"; fi' 'command -v pkill' \
         'kill -- -$(ps -o pgid= -p "$PID" | tr -d " ")' 'echo $(( (a)+(b) )); kill 123' 'ps -p "$pid" -o comm= && kill "$pid"' \
         'lsof -p "$pid" -nP && kill "$pid"'; do
  check "allows: $c" '[ "$(kill_rc "$c")" = 0 ]'
done
check "the kill guard refuses a command too long to check" '[ "$(kill_rc "echo $(printf "%0100001d" 0)")" = 2 ]'
check "the kill guard acts in the main checkout of an active run" '[ "$(kill_rc "pkill -f vite" "$d")" = 2 ]'
check "outside any idleflow run the kill guard allows a pattern kill" '[ "$(kill_rc "pkill -f vite" /nowhere)" = 0 ] && [ "$(kill_rc "kill \$(lsof -ti :3000)" /nowhere)" = 0 ]'
check "outside any idleflow run the kill guard allows a long command" '[ "$(kill_rc "echo $(printf "%0100001d" 0)" /nowhere)" = 0 ]'
check "a cd out of the run leaves the guard on for the run's session" '[ "$(kill_rc "pkill -f vite" /nowhere "$(native "$d")")" = 2 ]'
kg_start=$(date +%s); kg_rc=$(kill_rc "$(printf "%099999d" 0 | tr 0 "(")"); kg_secs=$(( $(date +%s) - kg_start ))
check "the kill guard gives up on a run of 99999 '(' within its time" "[ $kg_rc = 2 ] && [ $kg_secs -lt 8 ]"
check "the kill guard is a Bash hook" 'grep -q "kill-guard.sh" "$HERE/../hooks/hooks.json" && idleflow_rt get "$HERE/../hooks/hooks.json" hooks.PreToolUse | grep -q "\"matcher\":\"Bash\""'
check "every agent that runs commands has the process rule" '( for a in "$HERE"/../agents/*.md; do case "$a" in */classifier.md) continue;; esac; grep -q "Never end processes by name or pattern" "$a" || exit 1; done )'

echo "--- report / gate"
check "report fails when none written"  '! bash "$RUN" report T1 2>/dev/null'
( cd "$wt" && printf 'x\ny\nz\n' > src/code.py && printf '%s\n' $(seq 1 50) > README.md && printf 'task: T1\nstatus: done\n' > .idleflow-run/result.md && git add src/code.py README.md && commit -m "T1: code" )
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
# what is not committed never merges, so the gate does not count it and does not stage it
( cd "$wt" && seq 1 500 > src/generated.py && echo w >> src/code.py )
g="$(bash "$RUN" gate T1)"
check "gate counts only the task's commits" 'echo "$g" | grep -q "\"total\":3," && echo "$g" | grep -q "\"uncommitted\":2," && echo "$g" | grep -q "src/generated.py"'
check "gate leaves the task's index alone"  'git -C "$wt" diff --cached --quiet && [ -z "$(git -C "$wt" ls-files src/generated.py)" ]'
( cd "$wt" && seq 1 40 > src/big.py && git add src/big.py && commit -m "T1: big" )
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
m="$(bash "$RUN" merge T1 2>"$scratch/merge.err")"
check "merge stamps the task's merge"     '[[ "$(bash "$RUN" get tasks.T1.t_merge 2>/dev/null)" =~ ^[0-9]{10}$ ]]'
check "merge reports merged"           '[ "$m" = "merged T1" ]'
check "merged file on main"            '[ -f src/code.py ]'
check "merge takes commits, never uncommitted work" '[ ! -e src/generated.py ] && [ "$(cat src/code.py)" = "$(printf "x\ny\nz")" ] && grep -q "not merged: .*src/generated.py" "$scratch/merge.err"'
check "merge leaves untracked caches out" '[ ! -e .pytest_cache ] && ! git ls-files | grep -q pytest_cache'
check "merge keeps the human identity" '[ "$(git log -1 --format=%an)" = "Human" ]'
bash "$RUN" wt add TL > "$scratch/wl" 2>/dev/null
check "a task added after a merge branches from it"  '[ "$(bash "$RUN" get tasks.TL.base_sha)" = "$(git rev-parse HEAD)" ] && [ -f "$(cat "$scratch/wl")/src/code.py" ]'
bash "$RUN" wt rm TL
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
( cd "$wt2" && printf '1\n2\n3\n4\n5\n' > src/second.py && git add src/second.py && commit -m "T2: second" )
g2="$(bash "$RUN" gate T2)"
check "T2 gate sees only T2 lines (5)" 'echo "$g2" | grep -q "\"total\":5,"'
check "merge conflict exits 3"         '( cd "$wt2" && printf "changed\n" > src/code.py && git add src/code.py && commit -m "T2: change" ); printf "other\n" > src/code.py; git add -A; commit -m main-change; bash "$RUN" merge T2 >/dev/null 2>&1; [ $? -eq 3 ]'
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
sed -i.bak 's#^session_names: .*#session_names: per-person#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
mkdir -p docs/notes/ada && touch docs/notes/ada/s_0004.md
check "per-person notes number within the person's folder" '[ "$(IDLEFLOW_PERSON=ada bash "$RUN" session-name)" = "docs/notes/ada/s_0005.md" ] && [ "$(IDLEFLOW_PERSON=bob bash "$RUN" session-name)" = "docs/notes/bob/s_0001.md" ]'
git config --local idleflow.person "Grace H"
check "a named folder comes from idleflow.person" '[ "$(bash "$RUN" session-name)" = "docs/notes/Grace-H/s_0001.md" ]'
git config --local --unset idleflow.person
rm -rf docs
sed -i.bak 's#^progress_file: .*#progress_file: ../outside.md#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
check "a path outside the repo falls back"  'p="$(bash "$RUN" path progress 2>/dev/null)"; [ "$p" = "$top/progress.md" ] && bash "$RUN" path progress 2>&1 >/dev/null | grep -q "not a relative path"'
sed -i.bak 's#^progress_file: .*#progress_file: /abs/progress.md#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
check "an absolute path falls back"  'p="$(bash "$RUN" path progress 2>/dev/null)"; [ "$p" = "$top/progress.md" ] && bash "$RUN" path progress 2>&1 >/dev/null | grep -q "not a relative path"'
for bad in .git/hooks/post-commit docs/.GIT/x.md -progress.md; do
  sed -i.bak "s#^progress_file: .*#progress_file: $bad#" .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
  check "a path under .git or starting with - falls back ($bad)" '[ "$(bash "$RUN" path progress 2>/dev/null)" = "$top/progress.md" ]'
done
sed -i.bak 's#^progress_file: .*#progress_file: ./.docs/notes..md#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
printf 'time_log: .idleflow/time-log.md\n' >> .idleflow/conventions.md
check "a path in a dot folder is used without a warning" '[ "$(bash "$RUN" path time-log)" = "$top/.idleflow/time-log.md" ] && [ -z "$(bash "$RUN" path time-log 2>&1 >/dev/null)" ] && [ "$(bash "$RUN" path progress 2>/dev/null)" = "$top/.docs/notes..md" ] && [ -z "$(bash "$RUN" path progress 2>&1 >/dev/null)" ]'
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
sed -i.bak 's#^worktree_setup: .*#worktree_setup: mkdir -p "$MAIN/node_modules" \&\& ln -s "$MAIN/node_modules" node_modules#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
git add .idleflow/conventions.md && commit -q -m "linking setup"; bash "$RUN" approve worktree_setup >/dev/null
bash "$RUN" wt rm T7; bash "$RUN" finish done >/dev/null; bash "$RUN" new linking >/dev/null 2>&1
mkdir -p node_modules && echo keep > node_modules/dep.js
out="$(bash "$RUN" wt add T7 2>&1)"; rc=$?
check "a setup that links main's node_modules is refused" '[ "$rc" = 6 ] && echo "$out" | grep -q "linked node_modules to the main checkout" && [ ! -e .idleflow/worktrees/T7/node_modules ] && [ "$(cat node_modules/dep.js)" = keep ]'
rm -rf node_modules
bash "$RUN" wt rm T7; bash "$RUN" finish done >/dev/null
rm -rf shared-big; cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"

echo "--- setup after new: the run uses what setup committed"
cp .idleflow/conventions.md "$d-conv.bak"
sed -i.bak '/^shared_files:/d; /^gate:/d; /^preview:/d' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
git add .idleflow/conventions.md && commit -q -m "no shared files, no gate"
bash "$RUN" new late-setup >/dev/null 2>&1
check "new copies what conventions say now" '[ "$(idleflow_rt get .idleflow/runs/active/ownership.json shared)" = "[]" ] && [ -z "$(bash "$RUN" get gate)" ]'
printf 'shared_files: CHANGELOG.md\ngate: echo gate-ok\npreview: echo preview-ok\n' >> .idleflow/conventions.md
bash "$RUN" skip preview
bash "$RUN" snapshot >/dev/null
check "snapshot gives the run the shared files setup chose" '[ "$(idleflow_rt get .idleflow/runs/active/ownership.json shared)" = "[\"CHANGELOG.md\"]" ]'
check "snapshot gives the run the gate setup committed"     '[ "$(bash "$RUN" get gate)" = "echo gate-ok" ]'
check "a skipped command stays skipped after snapshot"      '[ -z "$(bash "$RUN" get preview)" ]'
check "skip refuses a key that is not a command"            '! bash "$RUN" skip mode 2>/dev/null'
bash "$RUN" wt add T8 >/dev/null 2>&1
sed -i.bak 's#^gate: .*#gate: echo changed#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
bash "$RUN" snapshot >/dev/null
check "once a task exists, the run's copy stays put"        '[ "$(bash "$RUN" get gate)" = "echo gate-ok" ]'
bash "$RUN" wt rm T8; bash "$RUN" finish done >/dev/null
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"

echo "--- parallel tasks share no port or temp folder"
bash "$RUN" new isolation >/dev/null 2>&1
wa="$(bash "$RUN" wt add TA 2>/dev/null)"; bash "$RUN" wt add TB >/dev/null 2>&1
pa="$(bash "$RUN" get tasks.TA.port)"; pb="$(bash "$RUN" get tasks.TB.port)"
check "each task gets its own port"            "[ '$pa' = 4400 ] && [ '$pb' = 4401 ]"
bash "$RUN" wt add TA >/dev/null 2>&1
check "a re-added task keeps its port"         '[ "$(bash "$RUN" get tasks.TA.port)" = 4400 ]'
out="$(bash "$RUN" exec TA -- sh -c 'echo "$IDLEFLOW_TASK $IDLEFLOW_PORT"; echo "$TMPDIR"; pwd')"
check "exec runs in the worktree with the task's port and temp folder" '[ "$(echo "$out" | sed -n 1p)" = "TA 4400" ] && echo "$out" | sed -n 2p | grep -q "/tasks/TA/tmp$" && [ "$(echo "$out" | sed -n 3p)" = "$(cd "$wa" && pwd)" ]'
check "exec runs the command without the agent's markers" '[ "$(CLAUDECODE=1 CLAUDE_CODE=1 AI_AGENT=claude CLAUDE_CODE_ENTRYPOINT=cli bash "$RUN" exec TA -- sh -c "echo \${CLAUDECODE-none} \${CLAUDE_CODE-none} \${AI_AGENT-none} \${CLAUDE_CODE_ENTRYPOINT-none}")" = "none none none none" ]'
check "exec passes the command's exit code"    'bash "$RUN" exec TA -- sh -c "exit 3"; [ $? = 3 ]'
inside="$(cd "$wa" && bash "$RUN" exec TA -- sh -c 'echo "$IDLEFLOW_PORT"')"
check "exec works from inside the task worktree" "[ '$inside' = 4400 ]"
bash "$RUN" wt rm TA; bash "$RUN" wt rm TB; bash "$RUN" finish done >/dev/null

echo "--- the repo's gate"
git add -u && commit -q -m "tidy before the gate"
cp .idleflow/conventions.md "$d-conv.bak"
printf 'gate: grep -q x src/keep.py && echo "gate-ok${CLAUDECODE:+ under an agent}"\n' >> .idleflow/conventions.md
git add .idleflow/conventions.md && commit -q -m "gate"
bash "$RUN" new gated >/dev/null 2>&1
printf 'dirty\n' >> src/keep.py; bash "$RUN" approve gate >/dev/null
check "the base gate refuses a dirty checkout" '! bash "$RUN" repo-gate base >/dev/null 2>&1'
git checkout -q -- src/keep.py; git config --local --unset idleflow.approved-gate
out="$(bash "$RUN" repo-gate base 2>&1)"; rc=$?
check "an unapproved gate never runs (exit 7)" '[ "$rc" = 7 ] && [ ! -e .idleflow/runs/active/repo-gate-base.log ]'
bash "$RUN" approve gate >/dev/null
out="$(CLAUDECODE=1 bash "$RUN" repo-gate base 2>/dev/null)"; rc=$?
check "the gate runs on the base and keeps its output" '[ "$rc" = 0 ] && echo "$out" | grep -q "^repo gate base: exit 0" && grep -qx gate-ok .idleflow/runs/active/repo-gate-base.log'
wg="$(bash "$RUN" wt add T4 2>/dev/null)"; ( cd "$wg" && echo y > src/keep.py )
out="$(bash "$RUN" repo-gate T4 2>/dev/null)"; rc=$?
check "a red gate in a task worktree exits 1" '[ "$rc" = 1 ] && echo "$out" | grep -q "^repo gate T4: exit 1" && [ -f .idleflow/runs/active/tasks/T4/repo-gate.log ]'
bash "$RUN" wt rm T4; bash "$RUN" finish done >/dev/null
check "the gate's time reaches the log"   'tail -1 .idleflow/runs/log.jsonl | grep -q "\"gate_seconds_max\":[0-9]"'
printf 'gate_quick: grep -q x src/keep.py && echo quick-ok\n' >> .idleflow/conventions.md
sed -i.bak 's#^gate: .*#gate: sleep 2; grep -q x src/keep.py#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
mkdir -p .husky && printf 'npm test\n' > .husky/pre-commit
git add .idleflow/conventions.md .husky && commit -q -m "slow gate"; bash "$RUN" approve gate >/dev/null; bash "$RUN" approve gate_quick >/dev/null
bash "$RUN" custom set SLOW_GATE_SECONDS 1 >/dev/null
bash "$RUN" new slow >/dev/null 2>&1
err="$(bash "$RUN" repo-gate base 2>&1 >/dev/null)"
check "a slow gate says so"               'echo "$err" | grep -q "^slow: the gate took [0-9]*s (over SLOW_GATE_SECONDS=1)"'
wq="$(bash "$RUN" wt add T3 2>/dev/null)"
out="$(bash "$RUN" repo-gate T3 --quick 2>/dev/null)"
check "--quick runs gate_quick in the task" 'echo "$out" | grep -q "^repo gate_quick T3: exit 0" && grep -q quick-ok .idleflow/runs/active/tasks/T3/repo-gate_quick.log'
( cd "$wq" && git -c user.name=t -c user.email=t@t commit -qam wip --allow-empty ); bash "$RUN" set tasks.T3.status '"approved"'
echo z > src/keep.py; git add src/keep.py; commit -q -m "main moves on"
out="$(bash "$RUN" repo-gate base 2>/dev/null)"; rc=$?
check "the base check runs at the recorded base after main moved" '[ "$rc" = 0 ] && echo "$out" | grep -q "^repo gate base: exit 0" && [ ! -d "$(dirname "$wq")/_gate-base" ]'
bash "$RUN" wt rm T3; bash "$RUN" finish done >/dev/null
det="$(bash "$RUN" detect)"
check "detect suggests gate_runs: once for a slow gate" 'echo "$det" | grep -q "^suggest gate_runs: once — the gate took"'
check "detect names a hook that runs tests" 'echo "$det" | grep -q "^suggest hooks: move the tests out of .husky/pre-commit —"'
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor shows hook advice without a fix it would apply" 'echo "$doc" | grep -q "^suggest fit hooks: .*idleflow never edits hooks"'
bash "$RUN" custom unset SLOW_GATE_SECONDS >/dev/null; rm -rf .husky; git checkout -q HEAD~1 -- src/keep.py 2>/dev/null || true
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"

echo "--- preview for screenshots"
cp .idleflow/conventions.md "$d-conv.bak"
printf 'preview: sleep 30\npreview_url: http://example.com:4173\n' >> .idleflow/conventions.md
git add .idleflow/conventions.md && commit -q -m "preview"
bash "$RUN" new preview >/dev/null 2>&1; bash "$RUN" wt add T2 >/dev/null 2>&1
bash "$RUN" preview T2 start >/dev/null 2>&1; rc=$?
check "an unapproved preview never runs (exit 7)" '[ "$rc" = 7 ] && [ ! -f .idleflow/runs/active/tasks/T2/preview.pid ]'
bash "$RUN" approve preview >/dev/null
check "a preview address off this machine is refused" '! bash "$RUN" preview T2 start >/dev/null 2>&1 && [ ! -f .idleflow/runs/active/tasks/T2/preview.pid ]'
sed -i.bak 's#^preview_url: .*#preview_url: http://localhost:4173#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
out="$(bash "$RUN" preview T2 start 2>/dev/null)"; pid="$(cat .idleflow/runs/active/tasks/T2/preview.pid 2>/dev/null)"
check "an approved preview starts and records its process" 'echo "$out" | grep -q "^preview T2: serving at http://localhost:4173" && kill -0 "$pid" 2>/dev/null'
bash "$RUN" preview T2 stop >/dev/null; sleep 1
check "preview stop ends it" '! kill -0 "$pid" 2>/dev/null && [ ! -f .idleflow/runs/active/tasks/T2/preview.pid ]'
bash "$RUN" wt rm T2; bash "$RUN" finish done >/dev/null
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"

echo "--- conventional commits"
cp .idleflow/conventions.md "$d-conv.bak"
printf 'commit_format: conventional\n' >> .idleflow/conventions.md
bash "$RUN" new conventional-commits-with-a-long-slug-name >/dev/null 2>&1
wc6="$(bash "$RUN" wt add T6 2>/dev/null)"
( cd "$wc6" && echo y >> src/keep.py && git add src/keep.py && commit -m "fix: keep y" )
printf '## Tasks\n\n### T6: keep the y line\n' > .idleflow/runs/active/plan.md
bash "$RUN" set tasks.T6.status '"approved"'; bash "$RUN" merge T6 >/dev/null 2>&1
subjects="$(git log -1 --format=%s HEAD)"; bodies="$(git log -1 --format=%b HEAD)"
cc_re='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([A-Za-z0-9_./-]+\))?!?: [^ ]'
check "the merge commit is a Conventional Commit" '[ "$(echo "$subjects" | grep -Ec "$cc_re")" = 1 ] && [ "$(echo "$subjects" | awk "length > 72" | wc -l | tr -d " ")" = 0 ]'
check "the run id moves to the commit body" '[ "$(echo "$bodies" | grep -c "^Run: ")" = 1 ] && echo "$bodies" | grep -qx "Task: T6"'
check "a conventional merge says what merged, not the tool" '[ "$subjects" = "chore: merge keep the y line" ]'
bash "$RUN" wt rm T6; bash "$RUN" finish done >/dev/null
sed -i.bak 's/^commit_format: .*/commit_format: plain/' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
bash "$RUN" new plain-subjects >/dev/null 2>&1
wc7="$(bash "$RUN" wt add T7 2>/dev/null)"
( cd "$wc7" && echo z >> src/keep.py && git add src/keep.py && commit -m "Keep the z line" )
git config merge.log true
# the title comes from the plan, so backticks and $ in it reach the subject as written
printf '%s\n' '### T70: Not this one' '### T7: Keep the `z` line, not $(z) or $HOME' > .idleflow/runs/active/plan.md
bash "$RUN" set tasks.T7.status '"approved"'; bash "$RUN" merge T7 >/dev/null 2>&1
git config --unset merge.log
check "a plain merge is a plain sentence with the ids in the body" '[ "$(git log -1 --format=%s HEAD)" = "Merge Keep the \`z\` line, not \$(z) or \$HOME" ] && git log -1 --format=%b HEAD | grep -qx "Task: T7" && git log -1 --format=%b HEAD | grep -q "^Run: "'
check "the ids stay trailers when merge.log is set" '[ "$(git log -1 --format="%(trailers:key=Run,valueonly,separator=)" HEAD)" = "$(bash "$RUN" get id)" ]'
long="$(printf "é%.0s" $(seq 1 80))"
check "a long title is cut by characters, never inside one" '[ "$(LC_ALL=C idleflow_rt clip 72 "Merge $long")" = "Merge $(printf "é%.0s" $(seq 1 63))..." ]'
bash "$RUN" wt rm T7; bash "$RUN" finish done >/dev/null
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"

echo "--- team"
check "session notes are named by time and author" 'bash "$RUN" session-name | grep -Eq "^docs/sessions/s_[0-9]{8}-[0-9]{4}-human\.md$"'
mkdir -p docs/sessions && touch "$(bash "$RUN" session-name)"
check "a second note in the same minute gets a suffix" 'bash "$RUN" session-name | grep -q -- "-human-2\.md$"'
rm -rf docs
cp .idleflow/conventions.md "$d-conv.bak"
sed -i.bak '/^ignore_in:/d' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak; printf 'ignore_in: gitignore\n' >> .idleflow/conventions.md
bash "$RUN" snapshot >/dev/null
check "snapshot sets union merges for shared logs" 'grep -qx ".idleflow/lessons.md merge=union" .gitattributes && grep -qx "progress.md merge=union" .gitattributes && git ls-files --error-unmatch .gitattributes >/dev/null 2>&1'
# ignore_in: exclude keeps idleflow out of committed files, merge rules included
cp .gitattributes "$d-attrs.bak"
sed -i.bak 's#^ignore_in: .*#ignore_in: exclude#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
git add .idleflow/conventions.md && commit -q -m "local rules"
attrs="$(git rev-parse --git-common-dir)/info/attributes"; rm -f "$attrs"
printf '.idleflow/suggestions.md\n' >> .git/info/exclude
bash "$RUN" snapshot >/dev/null
check "local merge rules go to .git/info/attributes" 'grep -qx "progress.md merge=union" "$attrs" && grep -qx ".idleflow/lessons.md merge=union" "$attrs" && cmp -s .gitattributes "$d-attrs.bak" && git diff --quiet HEAD -- .gitattributes'
check "an ignored record gets no merge rule"          '! grep -q "suggestions.md" "$attrs"'
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor reads the local merge rules"            'echo "$doc" | grep -q "^ok merges"'
grep -vxF '.idleflow/suggestions.md' .git/info/exclude > "$scratch/exclude"; cp "$scratch/exclude" .git/info/exclude; rm -f "$attrs"
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak" "$d-attrs.bak"; git add .idleflow/conventions.md && commit -q -m "shared rules again"
printf '{"permissions":{"allow":["Bash(ls)"]}}' > .claude/settings.json
bash "$RUN" team-install >/dev/null
check "team-install recommends idleflow, keeps the rest" '[ "$(idleflow_rt get .claude/settings.json enabledPlugins.idleflow@idlesync)" = "true" ] && [ "$(idleflow_rt get .claude/settings.json extraKnownMarketplaces.idlesync.source.repo)" = "Idle-Sync/idleflow" ] && grep -q "Bash(ls)" .claude/settings.json'
printf '{bad' > .claude/settings.json
bash "$RUN" team-install >/dev/null
check "team-install adds the CLAUDE.md note once" '[ "$(grep -c "idleflow install start" CLAUDE.md)" = "1" ] && grep -q "claude plugin install idleflow@idlesync" CLAUDE.md && grep -qF ".idleflow/lessons.md" CLAUDE.md'
check "team-install refuses broken JSON"  '! bash "$RUN" team-install 2>/dev/null && [ "$(cat .claude/settings.json)" = "{bad" ]'
printf '{}' > .claude/settings.json
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor's path check ignores the install note" 'echo "$doc" | grep -q "^ok paths"'
printf '# Index\n- `src/keep.py` code\n- `src/gone.py` removed\n- `origin/main` a branch\n```\nsrc/in-a-code-block.py\n```\n' > index.md
doc="$(bash "$RUN" doctor 2>/dev/null)"
check "doctor finds a path the docs name that is gone" 'echo "$doc" | grep -q "^warn paths: 1 path(s) the docs name do not exist: index.md: src/gone.py |"'
rm -f index.md
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

echo "--- detect: settings a repo with its own rules needs"
f="$(mktemp -d)"; ( cd "$f" && git init -q && git config user.name H && git config user.email h@h \
  && mkdir -p .idleflow docs/sessions tools && printf 'mode: repo\n' > .idleflow/conventions.md && echo l > lessons.md \
  && echo p > docs/progress.md && touch docs/sessions/s_0001.md && printf '# Index\n' > index.md \
  && printf '# Changelog\n## Unreleased\n' > CHANGELOG.md && printf 'Never write outside this folder.\n' > CLAUDE.md \
  && echo 'print(1)' > tools/gate.py && git add -A && git commit -qm "chore: start" \
  && for i in 1 2 3 4 5 6 7 8 9 10 11; do echo $i >> f; git add f; git commit -qm "feat(core): step $i"; done )
det="$(cd "$f" && bash "$RUN" detect)"
for want in "commit_format: conventional" "lessons_in: lessons.md" "progress_file: docs/progress.md" "session_names: numbered" "index_rewrite: no" "shared_files: CHANGELOG.md" "worktrees_in: inside" "gate: python3 tools/gate.py"; do
  check "detect suggests $want" 'echo "$det" | grep -qF "suggest $want —"'
done
( cd "$f" && printf 'commit_format: idleflow\n' >> .idleflow/conventions.md && mkdir -p .idleflow && printf -- '- declined: gate -> python3 tools/gate.py (doctor, today)\n' > .idleflow/suggestions.md )
det="$(cd "$f" && bash "$RUN" detect)"; doc="$(cd "$f" && bash "$RUN" doctor 2>/dev/null)"
check "detect leaves an answered key alone" '! echo "$det" | grep -q "^suggest commit_format"'
check "doctor hides a declined fit suggestion" '! echo "$doc" | grep -q "^suggest fit gate" && echo "$doc" | grep -q "^suggest fit lessons_in"'
rm -rf "$f"
f="$(mktemp -d)"; ( cd "$f" && git init -q && printf '{"scripts":{"dev":"vite"}}' > package.json )
det="$(cd "$f" && bash "$RUN" detect)"; det_rc=$?
check "detect works before the first commit" '[ "$det_rc" = 0 ] && echo "$det" | grep -q "^suggest preview: npm run dev —"'
check "doctor works before the first commit" '(cd "$f" && bash "$RUN" doctor >/dev/null 2>&1)'
rm -rf "$f"

echo "--- docs kept by code"
f="$(mktemp -d)"; ( cd "$f" && git init -q && git config user.name Ada && git config user.email a@a && mkdir -p .idleflow src \
  && printf 'mode: repo\n' > .idleflow/conventions.md && touch pnpm-lock.yaml \
  && printf '{"scripts":{"test":"vitest `run`"},"dependencies":{"react":"^19.0.0"}}' > package.json \
  && printf 'build:\n\tcc x\nVAR := 1\n' > Makefile && echo a > src/a.ts \
  && printf '# Progress\n\n## Milestones\n\n### M1: Sign in — users sign in\n- [x] a\n- [ ] b\n\n## Log\n<!-- progress start -->\n' > progress.md \
  && printf '# Index\n<!-- idleflow:generated files -->\n- `src/` — the app source\n- `gone/` — removed\n<!-- idleflow:end -->\n<!-- idleflow:generated commands -->\n<!-- idleflow:end -->\n<!-- idleflow:generated milestones -->\n<!-- idleflow:end -->\n<!-- idleflow:generated dependencies -->\n<!-- idleflow:end -->\n<!-- idleflow:generated runs -->\n<!-- idleflow:end -->\n' > index.md \
  && git add -A && git commit -qm "chore: start" \
  && git checkout -qb a && echo b > src/b.ts && git add -A && git commit -qm "feat: b" && git checkout -q - && git merge -q --no-ff -m "chore(idleflow): merge task T1" -m "Run: run-new" a \
  && git checkout -qb b && echo c > src/c.ts && git add -A && git commit -qm "c" && git checkout -q - && git merge -q --no-ff -m "idleflow: merge T2 (run-old)" b )
( cd "$f" && bash "$RUN" docs --check >/dev/null 2>&1 ); rc=$?
check "docs --check fails on stale blocks"  '[ "$rc" = 1 ]'
out="$(cd "$f" && bash "$RUN" docs)"; idx="$(cat "$f/index.md")"
check "docs regenerates in place"           'echo "$out" | grep -q "^docs: regenerated index.md"'
check "files keeps written descriptions, drops gone rows" 'echo "$idx" | grep -qxF -- "- \`src/\` — the app source" && ! echo "$idx" | grep -q "gone/" && echo "$idx" | grep -qxF -- "- \`package.json\` — (describe)"'
check "commands follow the package manager" 'echo "$idx" | grep -qxF -- "- \`pnpm test\` — runs \`vitest '"'"'run'"'"'\`" && echo "$idx" | grep -qxF -- "- \`make build\`" && ! echo "$idx" | grep -q "make VAR"'
check "commands start with the lockfile's install" 'echo "$idx" | grep -qxF -- "- \`pnpm install --frozen-lockfile\` — install (pnpm-lock.yaml)"'
check "milestones counted from progress"   'echo "$idx" | grep -qxF -- "- M1: Sign in: 1/2"'
check "dependencies read from the manifest" 'echo "$idx" | grep -qxF -- "- \`react\` ^19.0.0 — package.json"'
check "runs read from both merge formats"   'echo "$idx" | grep -q "run \`run-old\`, 1 task" && echo "$idx" | grep -q "run \`run-new\`, 1 task"'
( cd "$f" && bash "$RUN" docs --check >/dev/null 2>&1 ); rc=$?
check "a second docs run changes nothing"   '[ "$rc" = 0 ] && [ "$(cd "$f" && bash "$RUN" docs)" = "docs: generated blocks are up to date" ]'
( cd "$f" && git checkout -qb c && echo d > src/d.ts && git add -A && git commit -qm "d" && git checkout -q - && git merge -q --no-ff -m "Merge the d file" -m "Run: run-plain
Task: T3" c && bash "$RUN" docs >/dev/null )
check "runs are read from the Run trailer, whatever the subject" 'grep -q "run \`run-plain\`, 1 task" "$f/index.md" && grep -q "run \`run-old\`, 1 task" "$f/index.md"'
( cd "$f" && git add -A && git commit -qm "docs" && echo d > NOTES.md && git add -A && git commit -qm "d" )
doc="$(cd "$f" && bash "$RUN" doctor 2>/dev/null)"
check "doctor warns about a stale block"    'echo "$doc" | grep -q "^warn generated: out of date: index.md"'
check "doctor warns about undescribed entries" 'echo "$doc" | grep -q "^warn generated: [0-9]* generated entries still say (describe)"'
( cd "$f" && printf '# Index\n- `src/` — code\n' > index.md )
det="$(cd "$f" && bash "$RUN" detect)"
( cd "$f" && for i in $(seq 1 40); do echo "$i" > "p$i.txt"; git add "p$i.txt"; git commit -qm "Add the p$i notes"; done )
det="$(cd "$f" && bash "$RUN" detect)"
check "detect suggests plain subjects for a plain history" 'echo "$det" | grep -q "^suggest commit_format: plain —"'
check "detect suggests generated blocks for a hand-kept index" 'echo "$det" | grep -q "^suggest generated_docs: index.md —"'
( cd "$f" && git checkout -q -- index.md 2>/dev/null; printf '# Index\n<!-- idleflow:generated files -->\n<!-- idleflow:end -->\n' > index.md && echo x > é.txt && git add -A && git commit -qm "é" && bash "$RUN" docs >/dev/null )
check "the files block names non-ASCII files as they are" 'grep -qxF -- "- \`é.txt\` — (describe)" "$f/index.md"'
( cd "$f" && printf '# Index\n<!-- idleflow:generated files -->\n<!-- idleflow:end -->\n' > index.md && echo x > 'q"uote.txt' && git add -A && git commit -qm quote && bash "$RUN" docs >/dev/null )
check "the files block names any file as it is" 'grep -qxF -- "- \`q\"uote.txt\` — (describe)" "$f/index.md"'
rm -rf "$f"

echo "--- a first run fills Commands and can propose the gate"
f="$(mktemp -d)"; ( cd "$f" && git init -q && git config user.name Ada && git config user.email a@a && mkdir -p .idleflow \
  && cp "$HERE/../templates/conventions.md" .idleflow/conventions.md && cp "$HERE/../templates/CLAUDE.md" CLAUDE.md \
  && printf '{"scripts":{"test":"vitest run"}}' > package.json && printf '{}' > package-lock.json && git add -A && git commit -qm start )
( cd "$f" && bash "$RUN" docs >/dev/null )
check "CLAUDE.md Commands is filled from the repo"    'grep -qxF -- "- \`npm ci\` — install (package-lock.json)" "$f/CLAUDE.md" && grep -qxF -- "- \`npm run test\` — runs \`vitest run\`" "$f/CLAUDE.md"'
check "the template leaves the gate open to a proposal" '(cd "$f" && bash "$RUN" detect) | grep -q "^suggest gate: npm run test —"'
printf -- '- declined: gate -> npm run test (run r1)\n' > "$f/.idleflow/suggestions.md"
check "a declined gate is not proposed again"          '! (cd "$f" && bash "$RUN" detect) | grep -q "^suggest gate:"'
rm -rf "$f"
echo "--- a worktree builds its own Python environment"
f="$(mktemp -d)"; ( cd "$f" && git init -q && mkdir -p .idleflow .venv && printf 'mode: repo\nworktree_setup: unset\n' > .idleflow/conventions.md && printf '[project]\nname = "x"\n' > pyproject.toml )
check "detect suggests a worktree venv when main has one" '(cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup: py=.*-m venv .venv.*\.venv/Scripts/python\.exe.* -m pip install -q -e \. — the main checkout has .venv/"'
# a Windows-style python: no python3 on PATH, and its venv keeps the interpreter in Scripts/
cmd="$(cd "$f" && bash "$RUN" detect | sed -n 's/^suggest worktree_setup: \(.*\) — the main.*/\1/p')"
t="$(mktemp -d)"; mkdir -p "$t/bin" "$t/w"; ln -s "$(command -v mkdir)" "$t/bin/mkdir"; ln -s "$(command -v chmod)" "$t/bin/chmod"
cat > "$t/bin/python" <<'PY'
#!/bin/sh
if [ "$1" = -m ] && [ "$2" = venv ]; then
  mkdir -p "$3/Scripts"
  printf '#!/bin/sh\necho "$@" > ran\n' > "$3/Scripts/python.exe"; chmod +x "$3/Scripts/python.exe"
fi
PY
chmod +x "$t/bin/python"
( cd "$t/w" && PATH="$t/bin" "$(command -v bash)" -c "$cmd" )
check "the proposed venv command runs on a Windows layout" 'grep -qx -- "-m pip install -q -e ." "$t/w/ran"'
rm -rf "$t"
touch "$f/uv.lock"
check "a uv project syncs its own environment"   '(cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup: uv sync --frozen —"'
printf 'worktree_setup: make env\n' >> "$f/.idleflow/conventions.md"; sed -i.bak '/^worktree_setup: unset$/d' "$f/.idleflow/conventions.md"
check "a chosen worktree_setup is left alone"    '! (cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup"'
sed -i.bak 's/^worktree_setup: make env$/worktree_setup: none/' "$f/.idleflow/conventions.md"
check "worktree_setup: none is a decision"       '! (cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup"'
rm -rf "$f/.venv"; sed -i.bak '/^worktree_setup:/d' "$f/.idleflow/conventions.md"
check "no venv in main, no suggestion"           '! (cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup"'
rm -rf "$f"
check "agents never borrow the main checkout's environment" 'grep -q "never the main checkout" "$HERE/../agents/implementer.md" && grep -q "never the main checkout" "$HERE/../agents/implementer-hard.md" && grep -q "never the main checkout" "$HERE/../agents/review-correct.md"'
echo "--- which files run.sh docs keeps"
f="$(mktemp -d)"; ( cd "$f" && git init -q && git config user.name Ada && git config user.email a@a && mkdir -p .idleflow docs templates \
  && printf 'mode: repo\nindex_file: docs/index.md\n' > .idleflow/conventions.md && printf 'docs/\n' >> .git/info/exclude \
  && printf '# Progress\n\n## Milestones\n\n### M1: Sign in\n- [x] a\n- [x] b\n- [ ] c\n' > progress.md \
  && printf '# Index\n<!-- idleflow:generated milestones -->\n<!-- idleflow:end -->\n' > docs/index.md \
  && printf '# Index template\n<!-- idleflow:generated files -->\n<!-- idleflow:end -->\n' > templates/index.md \
  && printf '# Readme\n<!-- idleflow:generated milestones -->\n<!-- idleflow:end -->\n' > README.md \
  && git add -A && git commit -qm start )
out="$(cd "$f" && bash "$RUN" docs)"
check "docs fills an index kept out of git"   'echo "$out" | grep -q "docs/index.md" && grep -qxF -- "- M1: Sign in: 2/3" "$f/docs/index.md"'
( cd "$f" && git checkout -q -- templates README.md && printf 'generated_docs: README.md\n' >> .idleflow/conventions.md && git add -A && git commit -qm named )
out="$(cd "$f" && bash "$RUN" docs)"
check "generated_docs names the files kept"   '[ "$out" = "docs: regenerated README.md" ] && [ -z "$(cd "$f" && git status --porcelain templates)" ]'
( cd "$f" && git checkout -q -- README.md && sed -i.bak "s/^generated_docs: .*/generated_docs: none/" .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak )
check "generated_docs: none keeps no file"    '[ "$(cd "$f" && bash "$RUN" docs)" = "docs: generated blocks are up to date" ] && [ -z "$(cd "$f" && git status --porcelain README.md templates)" ]'
rm -rf "$f"

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
check "both reviewers allow shared files" 'grep -q "top-level \`shared\` list" "$HERE/../agents/review-conform.md" && grep -q "top-level \`shared\` list" "$HERE/../agents/review-correct.md"'
check "research agents reach sources by endpoint" '[ -f "$HERE/../procedures/research-sources.md" ] && grep -q "gh api repos" "$HERE/../procedures/research-sources.md" && ( for a in market-researcher stack-researcher library-scout; do grep -q "research-sources.md" "$HERE/../agents/$a.md" || exit 1; done ) && grep -q "research-sources.md" "$HERE/../commands/init.md" && [ "$(grep -o "research-sources.md" "$HERE/../procedures/repo-setup.md" | wc -l | tr -d " ")" -ge 2 ]'
check "the time log exists before the planner reads it" 'grep -q "copy \`templates/time-log.md\` if not" "$HERE/../commands/feature.md" && grep -q "copying \`templates/time-log.md\` if not" "$HERE/../commands/setup.md"'
check "human decisions reach the plan through the planner" 'grep -q "decisions.md" "$HERE/../agents/planner.md" && grep -q "Q<n>: answered" "$HERE/../agents/planner.md" && ! grep -q "apply the answer; continue" "$HERE/../commands/feature.md" && ! grep -q "write the answers into plan.md" "$HERE/../commands/feature.md" && grep -q "You never edit plan.md yourself" "$HERE/../commands/feature.md" && grep -q "Q1: <question> (default:" "$HERE/../templates/plan.md"'
check "attribution is one rule every commit writer gets" '( for a in implementer implementer-hard; do grep -q "in this repo this setting decides" "$HERE/../agents/$a.md" && grep -q "Claude-Session:" "$HERE/../agents/$a.md" || exit 1; done ) && grep -q "Claude-Session:" "$HERE/../agents/review-conform.md" && grep -q "Claude-Session:" "$HERE/../templates/CLAUDE.md" && [ "$(grep -c "co_author_claude: <value>" "$HERE/../commands/feature.md")" = 2 ]'
check "the doc-keeper edits sentences, never whole files" '! grep -q "^tools:.*Write" "$HERE/../agents/doc-keeper.md" && grep -q "belongs to humans" "$HERE/../agents/doc-keeper.md" && grep -q "as it is on disk now" "$HERE/../templates/CLAUDE.md"'
check "agents run task commands through run.sh exec" '( for a in implementer implementer-hard review-correct; do grep -q "exec <task-id> -- <command>" "$HERE/../agents/$a.md" || exit 1; done ) && grep -q "IDLEFLOW_PORT" "$HERE/../agents/planner.md" && [ "$(grep -c "exec <task-id> -- <command>\|exec <id> -- <command>" "$HERE/../commands/feature.md")" = 2 ]'
check "the index limit counts only hand-written text" 'grep -q "outside generated blocks) stays under 80 lines" "$HERE/../agents/retro.md" && grep -q "the text outside its generated blocks stays under 80 lines" "$HERE/../commands/setup.md" && ! grep -q "Under 80 lines\.\|), under 80 lines," "$HERE/../agents/retro.md" "$HERE/../commands/setup.md"'
check "the designer and design reviewer exist" '[ -f "$HERE/../agents/designer.md" ] && [ -f "$HERE/../agents/review-design.md" ] && grep -q "\"ui\"" "$HERE/../agents/classifier.md" && grep -q "^### 2c. Design" "$HERE/../commands/feature.md"'
check "the design handbook carries the contrast rule" 'grep -q "4.5:1" "$HERE/../procedures/design.md" && grep -q "0.2126 R + 0.7152 G + 0.0722 B" "$HERE/../procedures/design-data.md"'
check "STEP_DESIGN is a setting" 'grep -q STEP_DESIGN "$HERE/conf.sh" && grep -q "^STEP_DESIGN=auto" "$HERE/../config/idleflow.conf"'
check "every command reads the talking rules" '[ -z "$(cd "$HERE/../commands" && grep -L "procedures/talking.md" *.md | grep -vx fix.md)" ]'
check "R3 chunks and concatenates"      'grep -q "stack-research-<n>.md" "$setup" && grep -q "\`cat\` them in order into \`.idleflow/runs/active/stack-research.md\` before step 3" "$setup"'

echo
if [ "$fails" -eq 0 ]; then echo "PASS ($(idleflow_rt_name))"; else echo "FAIL: $fails check(s)"; exit 1; fi
