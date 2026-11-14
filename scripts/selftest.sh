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

# Every check's test is single-quoted on purpose, so check() expands it when it runs: shellcheck
# then sees neither the expansion (SC2016) nor the variables the test reads (SC2034).
# shellcheck disable=SC2016,SC2034
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
cleanup() { cd / ; rm -rf "$d" "$d-tmp" "${d}__wt" "$d.link" "${d}__wt.link" "$d-mig" "$d-human" "${d}-human__wt" "$d-stray" "$d-pin" 2>/dev/null || true; }
trap cleanup EXIT
# the suite's own root for task temp folders and port claims, so a suite running beside it never meets it
export IDLEFLOW_TMP_ROOT="$d-tmp"; mkdir -p "$IDLEFLOW_TMP_ROOT"; utmp="$IDLEFLOW_TMP_ROOT/idleflow-$(id -u)"

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
check "an id git, Windows or run.json keys cannot use is refused" '! bash "$RUN" wt add "a~1" 2>/dev/null && ! bash "$RUN" wt add "x.lock" 2>/dev/null && ! bash "$RUN" wt add T1.a 2>/dev/null && [ -z "$(bash "$RUN" get tasks.T1.a 2>/dev/null)" ] && ! bash "$RUN" wt add _gate-base 2>/dev/null && ! bash "$RUN" wt add CON 2>/dev/null'
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
check "debate round 2 runs red first, then cost answers it" 'grep -q "a second miss stops the run), \`idleflow:cost-critic\` → \`debate/round-2-cost.md\`, with the round-1 inputs, \`round-1-red.md\` and \`round-2-red.md\`" "$HERE/../commands/feature.md" && grep -q "round-1 and round-2 files (round 2 runs after the red team" "$HERE/../agents/cost-critic.md" && grep -q "round 2 runs before the cost critic" "$HERE/../agents/red-team.md" && ! grep -q "Round 2, both in parallel" "$HERE/../commands/feature.md" && grep -q "cuts their round-2 file objected to" "$HERE/../agents/cost-critic.md" && ! grep -q "drop any the cost critic answered" "$HERE/../agents/red-team.md" && grep -q "drop any finding made moot by a cut you did not object to" "$HERE/../agents/red-team.md"'
check "tests that use changed code reach the plan's ownership" 'grep -q "grep the whole test tree" "$HERE/../agents/explorer.md" && grep -q "Other tests using what changes" "$HERE/../templates/context.md" && grep -q "each test, fake or fixture context.md §4 lists as using a symbol the task alters goes in that task" "$HERE/../agents/planner.md"'
check "the session template and CLAUDE.md block follow a relocated sessions folder" 'grep -q "path progress|index|sessions\`)" "$HERE/../commands/feature.md" && grep -q "the sessions folder," "$HERE/../agents/retro.md" && grep -q "\`TEMPLATE.md\` in the sessions folder your prompt names" "$HERE/../agents/retro.md" && ! grep -q "fill \`docs/sessions/TEMPLATE.md\`" "$HERE/../agents/retro.md" && grep -q "repo-relative paths \`bash \"\$RUN\" path --relative progress|index|sessions\`" "$HERE/../procedures/repo-setup.md" && grep -q "the sessions folder (\`bash \"\$RUN\" path sessions\`), \`.idleflow/conventions.md\`" "$HERE/../commands/feature.md"'
check "only Claude Code configuration under .claude/ is protected, and the planner knows the list" 'for f in agents/planner.md commands/feature.md; do grep -q "\`.claude/settings.json\`, \`.claude/settings.local.json\`, \`.claude/agents/\`" "$HERE/../$f" || exit 1; done && ! grep -q "under \`.idleflow/\` or \`.claude/\`" "$HERE/../commands/feature.md" && grep -q "tracked skills and commands" "$HERE/../agents/planner.md"'
check "doc-keeper's Bash write ban leaves its gaps.md append allowed" 'grep -q "never change a doc or any other tracked file through Bash" "$HERE/../agents/doc-keeper.md" && grep -q "The one write Bash may make is the single-line append to the run.s \`gaps.md\`" "$HERE/../agents/doc-keeper.md" && ! grep -q "never write a file through Bash" "$HERE/../agents/doc-keeper.md"'
# unpinned_actions <workflows dir>: prints each uses: line that is not pinned; exit 2 when there is no workflow.
# Pinned: a 40-hex commit, a docker image by sha256 digest, or a local ./ action (fixed by the checkout).
unpinned_actions() {
  local f files=()
  for f in "$1"/*.yml "$1"/*.yaml; do [ -f "$f" ] && files+=("$f"); done
  [ "${#files[@]}" -gt 0 ] || return 2
  grep -hE '(^|[{,])[[:space:]]*-?[[:space:]]*uses:' "${files[@]}" \
    | grep -vE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*["'\'']?([^@[:space:]"'\'']+@[0-9a-f]{40}|docker://[^@[:space:]"'\'']+@sha256:[0-9a-f]{64}|\./[^[:space:]"'\'']*)["'\'']?[[:space:]]*(#.*)?$' || true
}
pin="$d-pin"; mkdir -p "$pin/a" "$pin/b" "$pin/c" "$pin/none"
printf '    steps:\n      - uses: a/b@%s # v1\n      - uses: ./.github/actions/x\n      - uses: docker://alpine@sha256:%s\n' "$(printf '%040d' 0 | tr 0 a)" "$(printf '%064d' 0 | tr 0 b)" > "$pin/a/ok.yml"
printf '      - uses: a/b@v4\n' > "$pin/b/late.yaml"
printf '      - {uses: a/b@v4}\n      - uses: a/b@v4 # uses: a/b@%s\n' "$(printf '%040d' 0 | tr 0 a)" > "$pin/c/sly.yml"
check "every CI action is pinned to a commit, and Dependabot bumps them" 'out="$(unpinned_actions "$HERE/../.github/workflows")" && [ -z "$out" ] && grep -q "package-ecosystem: github-actions" "$HERE/../.github/dependabot.yml"'
check "the pin check reads .yaml, flow and commented forms, and needs a workflow" '[ -z "$(unpinned_actions "$pin/a")" ] && [ -n "$(unpinned_actions "$pin/b")" ] && [ "$(unpinned_actions "$pin/c" | grep -c .)" = 2 ] && { unpinned_actions "$pin/none"; [ $? = 2 ]; }'
check "every unverified check is written where the reports read it" 'for a in implementer implementer-hard; do grep -q "blocked_on: <none | file + reason | environment: <the cause> — <the quoted output line>>" "$HERE/../agents/$a.md" || exit 1; done && grep -q "appends \`- repo gate on main — environment:" "$HERE/../commands/feature.md" && grep -q "write \`review/merged-design.md\` with an \`unverified:\` line" "$HERE/../commands/feature.md" && grep -q "of \`review/merged-correct.md\` and \`review/merged-design.md\`" "$HERE/../commands/feature.md" && grep -q "an \`environment:\` entry as the check to run once its cause is fixed" "$HERE/../agents/retro.md"'
check "every plan is checked by plan-check, and the planner knows what it checks" 'grep -q "after this and every later planner call that writes plan.md (a revision, a split): \`bash \"\$RUN\" plan-check\`" "$HERE/../commands/feature.md" && grep -q "which \`run.sh plan-check\` checks" "$HERE/../agents/planner.md"'
check "a fix round names what it could not fix apart from the build's deviations" 'for a in implementer implementer-hard; do grep -q "^unfixed: <none | Fix mode only" "$HERE/../agents/$a.md" && grep -q "name it under \`unfixed\`, never under \`deviations\`" "$HERE/../agents/$a.md" || exit 1; done && grep -q "report names a finding under \`unfixed:\`" "$HERE/../commands/feature.md" && ! grep -q "fix round.s report named a deviation" "$HERE/../commands/feature.md" && grep -q "\`blocked_on:\` and \`unfixed:\` that is not" "$HERE/../commands/endsession.md"'
check "a task the plan cannot finish yet is marked, revised before its group, and named in the template" 'grep -q "^blocked_until: none " "$HERE/../templates/plan.md" && grep -q "give it \`blocked_until: revision" "$HERE/../agents/planner.md" && grep -q "^0\. \*\*Blocked tasks first\.\*\*" "$HERE/../commands/feature.md"'
check "the agents that judge the plan get the issue" '( for a in planner red-team cost-critic; do grep -q "issue.md" "$HERE/../agents/$a.md" || exit 1; done ) && grep -q "Spawn \`idleflow:planner\` with: the issue path" "$HERE/../commands/feature.md" && grep -q "each with the issue, plan.md and context.md paths" "$HERE/../commands/feature.md"'
check "agents that run suites wait on long checks as jobs" '( for a in implementer implementer-hard review-correct; do grep -q "run.sh>\" wait <task-id> <n>" "$HERE/../agents/$a.md" && grep -q "Never start it again while it runs" "$HERE/../agents/$a.md" || exit 1; done )'

echo "--- keep"
printf 'plan v1\n' > .idleflow/runs/active/plan.md
k1="$(bash "$RUN" keep plan.md)"; printf 'plan v2\n' > .idleflow/runs/active/plan.md
k2="$(bash "$RUN" keep plan.md)"
check "keep copies the plan aside, numbered in order" '[ "$(cat "$k1")" = "plan v1" ] && [ "$(cat "$k2")" = "plan v2" ] && [ -f .idleflow/runs/active/plan.1.md ] && [ -f .idleflow/runs/active/plan.2.md ] && [ "$(cat .idleflow/runs/active/plan.md)" = "plan v2" ]'
printf 'verdict: reject\n' > .idleflow/runs/active/review/T1-correct.md
bash "$RUN" keep --move review/T1-correct.md >/dev/null
check "keep --move frees the name for the next review" '[ ! -e .idleflow/runs/active/review/T1-correct.md ] && grep -q reject .idleflow/runs/active/review/T1-correct.1.md'
check "keep refuses a path outside the run or a missing file" '! bash "$RUN" keep ../run.json 2>/dev/null && ! bash "$RUN" keep /etc/hosts 2>/dev/null && ! bash "$RUN" keep review/none.md 2>/dev/null'
rm .idleflow/runs/active/plan.1.md
check "keep numbers past the highest kept version, not into a gap" '[ "$(basename "$(bash "$RUN" keep plan.md)")" = plan.3.md ]'
check "keep with no file says what it needs" '! bash "$RUN" keep 2>&1 >/dev/null | grep -q unbound && ! bash "$RUN" keep 2>/dev/null'
rm .idleflow/runs/active/plan.md .idleflow/runs/active/plan.2.md .idleflow/runs/active/plan.3.md .idleflow/runs/active/review/T1-correct.1.md
check "usage lists every command in the header" '[ "$(bash "$RUN" 2>/dev/null | grep -c "^#   run.sh ")" = "$(grep -c "^#   run.sh " "$RUN")" ]'

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

echo "--- reword / findings"
first="$(git -C "$wt" rev-parse HEAD~1)"; second="$(git -C "$wt" rev-parse HEAD)"; tree="$(git -C "$wt" rev-parse "HEAD^{tree}")"
author="$(git -C "$wt" log -1 --format='%an <%ae> %ad' "$first")"
printf 'T1: add the code\n\nTask: T1\n' > "$scratch/m1"; printf "T1: add the big file, it's \"quoted\"\n" > "$scratch/m2"
printf '\n  \n' > "$scratch/blank"
check "reword refuses a commit outside the task, a blank message, a sha twice" '! bash "$RUN" reword T1 "$(git rev-parse HEAD)" "$scratch/m1" 2>/dev/null && ! bash "$RUN" reword T1 "$first" "$scratch/none" 2>/dev/null && ! bash "$RUN" reword T1 "$first" 2>/dev/null && ! bash "$RUN" reword T1 "$first" "$scratch/blank" 2>/dev/null && ! bash "$RUN" reword T1 "$first" "$scratch/m1" "$first" "$scratch/m2" 2>/dev/null && [ "$(git -C "$wt" rev-parse HEAD)" = "$second" ]'
bash "$RUN" reword T1 "$first" "$scratch/m1" "$second" "$scratch/m2" >/dev/null
check "reword gives every flagged commit its message, older ones too" '[ "$(git -C "$wt" log -1 --format=%B HEAD~1)" = "$(cat "$scratch/m1")" ] && [ "$(git -C "$wt" log -1 --format=%s HEAD)" = "$(head -n1 "$scratch/m2")" ] && [ "$(git -C "$wt" rev-list --count "$(bash "$RUN" get tasks.T1.base_sha)..HEAD")" = 2 ]'
check "reword changes no file, author or uncommitted work" '[ "$(git -C "$wt" rev-parse HEAD^{tree})" = "$tree" ] && [ "$(git -C "$wt" log -1 --format="%an <%ae> %ad" HEAD~1)" = "$author" ] && ! git -C "$wt" diff --quiet -- src/code.py && [ -f "$wt/src/generated.py" ]'
printf 'verdict: approve\nremedy: none\nfindings:\n### F1. A weak assertion   severity: minor\n### F2. A leak on the error path   severity: major\n' > .idleflow/runs/active/review/T1-correct.md
printf '### F9. Fixed since   severity: blocking\n' > .idleflow/runs/active/review/T1-correct.1.md
printf '### F1. Not this task   kind: convention\n' > .idleflow/runs/active/review/T10-conform.md
printf '### F1. Nor this one   kind: convention\n' > .idleflow/runs/active/review/T1-ui-conform.md
printf '### D1. A hyphenated task id   severity: minor\n' > .idleflow/runs/active/review/T1-2-design.md
f="$(bash "$RUN" findings T1)"
check "findings lists the current reviews' findings only" '[ "$(echo "$f" | wc -l | tr -d " ")" = 2 ] && echo "$f" | grep -qx "T1: F2. A leak on the error path   severity: major (review/T1-correct.md)" && ! echo "$f" | grep -q "F9\|Not this task\|Nor this one"'
check "findings reads a hyphenated task id's current review" '[ "$(bash "$RUN" findings T1-2)" = "T1-2: D1. A hyphenated task id   severity: minor (review/T1-2-design.md)" ]'
rm .idleflow/runs/active/review/T1-correct.md .idleflow/runs/active/review/T1-correct.1.md .idleflow/runs/active/review/T10-conform.md .idleflow/runs/active/review/T1-ui-conform.md .idleflow/runs/active/review/T1-2-design.md

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
check "path --relative prints the configured record paths repo-relative" '[ "$(bash "$RUN" path --relative progress)" = "docs/progress.md" ] && [ "$(bash "$RUN" path --relative index)" = "docs/index.md" ] && [ "$(bash "$RUN" path --relative sessions)" = "docs/notes" ] && ! bash "$RUN" path --relative runs 2>/dev/null'
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
out="$(bash "$RUN" exec T8 --base -- echo ran 2>&1)"; rc=$?; out2="$(bash "$RUN" exec T8 --base -- echo ran 2>&1)"; rc2=$?
check "a base checkout whose setup fails exits 6 each time and runs nothing" '[ "$rc" = 6 ] && [ "$rc2" = 6 ] && ! printf "%s\n%s\n" "$out" "$out2" | grep -qx ran && [ ! -d .idleflow/worktrees/_base-T8 ]'
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
check "exec runs in the worktree with the task's port and temp folder" '[ "$(echo "$out" | sed -n 1p)" = "TA 4400" ] && echo "$out" | sed -n 2p | grep -q "^$utmp/[0-9a-f]\{10\}/TA$" && [ "$(echo "$out" | sed -n 3p)" = "$(cd "$wa" && pwd)" ]'
check "exec runs the command without the agent's markers" '[ "$(CLAUDECODE=1 CLAUDE_CODE=1 AI_AGENT=claude CLAUDE_CODE_ENTRYPOINT=cli bash "$RUN" exec TA -- sh -c "echo \${CLAUDECODE-none} \${CLAUDE_CODE-none} \${AI_AGENT-none} \${CLAUDE_CODE_ENTRYPOINT-none}")" = "none none none none" ]'
check "exec passes the command's exit code"    'bash "$RUN" exec TA -- sh -c "exit 3"; [ $? = 3 ]'
inside="$(cd "$wa" && bash "$RUN" exec TA -- sh -c 'echo "$IDLEFLOW_PORT"')"
check "exec works from inside the task worktree" "[ '$inside' = 4400 ]"
# Ports are claimed across the machine: another repo's live run holds 4402, something else listens
# on 4403, a claim left by a run that has ended holds 4404, and another run is deciding about 4405.
o="$d-tmp/other"; mkdir -p "$o/.idleflow/runs/active" "$utmp/ports/4405.lock"
printf '{"id":"r1","tasks":{"T9":{"port":4402}}}\n' > "$o/.idleflow/runs/active/run.json"
printf '%s\tr1\tT9\n' "$o" > "$utmp/ports/4402"
printf '%s\tgone\tT1\n' "$o" > "$utmp/ports/4404"
listen_args=(node -e 'const s=require("net").createServer().listen(4403,"127.0.0.1",()=>console.log("up"));setTimeout(()=>s.close(),20000)')
command -v node >/dev/null 2>&1 || listen_args=(python3 -c 'import socket,time;s=socket.socket();s.bind(("127.0.0.1",4403));s.listen();print("up",flush=True);time.sleep(20)')
"${listen_args[@]}" > "$d-tmp/listen.out" 2>&1 & lpid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q up "$d-tmp/listen.out" 2>/dev/null && break; sleep 0.3; done
bash "$RUN" wt add TC >/dev/null 2>&1; bash "$RUN" wt add TD >/dev/null 2>&1
kill "$lpid" 2>/dev/null; wait "$lpid" 2>/dev/null; rmdir "$utmp/ports/4405.lock"
check "a port another live run claims, something listens on, or another run is deciding about is skipped" '[ "$(bash "$RUN" get tasks.TC.port)" = 4404 ] && [ "$(bash "$RUN" get tasks.TD.port)" = 4406 ]'
check "a stale claim is taken over, with this run as its owner" '[ "$(cut -f2,3 "$utmp/ports/4404")" = "$(bash "$RUN" get id)	TC" ] && [ ! -e "$utmp/ports/4403" ] && [ ! -e "$utmp/ports/4405" ]'
check "the claim of a live run elsewhere stays its own" '[ "$(cut -f2,3 "$utmp/ports/4402")" = "r1	T9" ]'
# a lock whose holder has died is taken over; 4403 is free again now its listener has gone
sh -c 'exit 0' & dead=$!; wait "$dead"; mkdir -p "$utmp/ports/4403.lock"; echo "$dead" > "$utmp/ports/4403.lock/pid"
bash "$RUN" wt add TE >/dev/null 2>&1
check "a port lock whose holder has died is taken over and given back" '[ "$(bash "$RUN" get tasks.TE.port)" = 4403 ] && [ ! -e "$utmp/ports/4403.lock" ]'
mkdir "$utmp/ports/4405.lock"; bash "$RUN" wt add TF >/dev/null 2>&1; rmdir "$utmp/ports/4405.lock"
check "a port lock that names no holder yet is still skipped" '[ "$(bash "$RUN" get tasks.TF.port)" = 4407 ]'
# a dead holder's lock that another run is already taking over is left to it
mkdir -p "$utmp/ports/4405.lock" "$utmp/ports/4405.lock.takeover"; echo "$dead" > "$utmp/ports/4405.lock/pid"
bash "$RUN" wt add TG >/dev/null 2>&1
check "a dead lock another run is taking over is skipped" '[ "$(bash "$RUN" get tasks.TG.port)" = 4408 ] && [ "$(cat "$utmp/ports/4405.lock/pid")" = "$dead" ]'
rm -f "$utmp/ports/4405.lock/pid"; rmdir "$utmp/ports/4405.lock" "$utmp/ports/4405.lock.takeover"
check "a task's temp folder is short and outside the repo" 't="$(bash "$RUN" exec TA -- sh -c "echo \$TMPDIR")"; [ "${#t}" -eq $(( ${#utmp} + 14 )) ] && [ -d "$t" ] && case "$t" in "$d"/*) false;; *) true;; esac'
mkdir -p "$d-tmp/r2" "$d-tmp/elsewhere"; ln -s "$d-tmp/elsewhere" "$d-tmp/r2/idleflow-$(id -u)"
check "a user folder under the temp root that is a symlink is refused" '! IDLEFLOW_TMP_ROOT="$d-tmp/r2" bash "$RUN" exec TA -- true 2>/dev/null && [ -z "$(ls -A "$d-tmp/elsewhere")" ]'
check "the user folder is private" '[ "$(ls -ld "$utmp" | cut -c1-10)" = drwx------ ]'
# Python reuses bytecode while a source keeps its size and whole-second mtime (pinned here to a stamp);
# -I ignores PYTHON* variables, as tox's environments do, so only clearing the bytecode helps
py_ok=no; _idleflow_py_ok python3 && py_ok=yes
import_m=(python3 -I -c "import sys; sys.path.insert(0, '.'); import m; print(m.x)")
touch "$scratch/stamp"
pin_m() { echo "x = $2" > "$1/m.py"; touch -r "$scratch/stamp" "$1/m.py"; }
unpin_m() { rm -f "$1/m.py" "$1"/__pycache__/m.*.pyc; rmdir "$1/__pycache__" 2>/dev/null || true; }
if [ "$py_ok" = yes ]; then
  pin_m "$wa" 1; ( cd "$wa" && "${import_m[@]}" >/dev/null ); pin_m "$wa" 2
  check "a same-size edit runs stale bytecode outside exec (the case below is real)" '[ "$(cd "$wa" && "${import_m[@]}")" = 1 ]'
  check "exec runs the source as it is, not an earlier command's bytecode" '[ "$(bash "$RUN" exec TA -- "${import_m[@]}")" = 2 ]'
  pin_m "$wa" 3
  check "the next exec runs the next same-size edit" '[ "$(bash "$RUN" exec TA -- "${import_m[@]}")" = 3 ]'
  unpin_m "$wa"
  mkdir -p "$wa/pkg/__pycache__"; : > "$wa/pkg/kept.py"; : > "$wa/pkg/__pycache__/kept.cpython-0.pyc"
  git -C "$wa" add pkg && git -C "$wa" -c user.name=t -c user.email=t@t commit -qm "tracked bytecode"
  bash "$RUN" exec TA -- true >/dev/null 2>&1
  check "exec leaves bytecode the repo tracks alone" '[ -f "$wa/pkg/__pycache__/kept.cpython-0.pyc" ] && [ -z "$(git -C "$wa" status --porcelain --untracked-files=no)" ]'
  git -C "$wa" reset -q --hard HEAD~1
  if [ "$(id -u)" != 0 ]; then
    mkdir -p "$wa/pkg/__pycache__"; : > "$wa/pkg/stuck.py"; : > "$wa/pkg/__pycache__/stuck.cpython-0.pyc"; chmod a-w "$wa/pkg/__pycache__"
    out="$(bash "$RUN" exec TA -- echo ran 2>&1)"
    check "bytecode exec cannot remove is named and the command still runs" 'echo "$out" | grep -q "could not remove stale bytecode: .*stuck.cpython-0.pyc" && echo "$out" | grep -qx ran'
    chmod u+w "$wa/pkg/__pycache__"; rm -f "$wa/pkg/stuck.py" "$wa/pkg/__pycache__/stuck.cpython-0.pyc"; rmdir "$wa/pkg/__pycache__" "$wa/pkg"
  fi
fi
[ ! -f .idleflow/idleflow.conf ] || cp .idleflow/idleflow.conf "$scratch/conf.bak"
printf 'EXEC_WAIT_SECONDS=1\n' >> .idleflow/idleflow.conf
bash "$RUN" exec TA -- sh -c 'sleep 3; echo slow-done; exit 4' > "$scratch/job.out" 2> "$scratch/job.err"; rc=$?
check "exec returns 75 and names the job while a command runs on" '[ "$rc" = 75 ] && n="$(sed -n "1s/^\[idleflow\] job \([0-9]*\) of TA started$/\1/p" "$scratch/job.err")" && [ -n "$n" ] && grep -q "job $n of TA is still running" "$scratch/job.err"'
job="$(sed -n 's/.*job \([0-9]*\) of TA is still running.*/\1/p' "$scratch/job.err")"
for _ in 1 2 3 4 5; do bash "$RUN" wait TA "$job" > "$scratch/job.out" 2>/dev/null; rc=$?; [ "$rc" = 75 ] || break; done
check "wait gives the same job's output and exit code when it ends" '[ "$rc" = 4 ] && grep -qx slow-done "$scratch/job.out"'
bash "$RUN" exec TA -- sh -c 'sleep 60 & echo "$!" > child.pid; wait' >/dev/null 2> "$scratch/job.err"
job="$(sed -n 's/.*job \([0-9]*\) of TA is still running.*/\1/p' "$scratch/job.err")"
bash "$RUN" stop TA "$job" >/dev/null
check "stop ends the job and the processes it started" '! kill -0 "$(cat "$wa/child.pid")" 2>/dev/null && ! bash "$RUN" wait TA "$job" >/dev/null 2>&1'
bash "$RUN" exec TA --limit 2 -- sh -c 'sleep 60 & echo "$!" > child.pid; wait' >/dev/null 2> "$scratch/job.err"
job="$(sed -n 's/.*job \([0-9]*\) of TA is still running.*/\1/p' "$scratch/job.err")"
for _ in 1 2 3 4 5; do bash "$RUN" wait TA "$job" >/dev/null 2> "$scratch/job.err"; rc=$?; [ "$rc" = 75 ] || break; done
check "a job past its --limit is stopped with what it started and exits 124" '[ "$rc" = 124 ] && grep -q "passed its limit of 2 s" "$scratch/job.err" && ! kill -0 "$(cat "$wa/child.pid")" 2>/dev/null && [ "$(cat .idleflow/runs/active/tasks/TA/jobs/$job/status)" = 124 ]'
check "a job within its --limit passes its exit code" 'bash "$RUN" exec TA --limit 30 -- sh -c "exit 3" 2>/dev/null; [ $? = 3 ]'
bash "$RUN" exec TA --limit 2 -- sleep 1.5 >/dev/null 2> "$scratch/job.err"; rc=$?
job="$(sed -n 's/.*job \([0-9]*\) of TA started.*/\1/p' "$scratch/job.err")"
for _ in 1 2 3 4 5; do [ "$rc" = 75 ] || break; bash "$RUN" wait TA "$job" >/dev/null 2> "$scratch/job.err"; rc=$?; done
check "a job gets its whole --limit and says how long it ran" '[ "$rc" = 0 ] && grep -q "^\[idleflow\] job $job of TA ran for [12] s$" "$scratch/job.err"'
check "exec refuses a --limit that is not whole seconds" '! bash "$RUN" exec TA --limit 0 -- true 2>/dev/null && ! bash "$RUN" exec TA --limit 1.5 -- true 2>/dev/null && ! bash "$RUN" exec TA --limit -- true 2>/dev/null'
bash "$RUN" exec TA -- sh -c 'sleep 30 >/dev/null 2>&1 &' >/dev/null 2> "$scratch/job.err"; rc=$?
job="$(sed -n 's/.*job \([0-9]*\) of TA started.*/\1/p' "$scratch/job.err")"
check "a job that leaves a process behind ends with its code and says so" '[ "$rc" = 0 ] && grep -q "job $job of TA ended, but processes it started still run" "$scratch/job.err" && bash "$RUN" stop TA "$job" >/dev/null && [ -f .idleflow/runs/active/tasks/TA/jobs/$job/ended ]'
sleep 300 >/dev/null 2>&1 & other=$!
echo "$other" > ".idleflow/runs/active/tasks/TA/jobs/$job/pid"
check "an ended job is never signalled again" 'bash "$RUN" stop TA "$job" >/dev/null && kill -0 "$other" 2>/dev/null'
bash "$RUN" exec TA -- true >/dev/null 2> "$scratch/job.err"
job="$(sed -n 's/.*job \([0-9]*\) of TA started.*/\1/p' "$scratch/job.err")"; rm -f ".idleflow/runs/active/tasks/TA/jobs/$job/ended"
echo "$other" > ".idleflow/runs/active/tasks/TA/jobs/$job/pid"
check "a finished job whose pid was reused is never signalled" 'bash "$RUN" stop TA "$job" >/dev/null && kill -0 "$other" 2>/dev/null'
kill "$other" 2>/dev/null
( cd "$wa" && echo new > only-in-task.txt && git add only-in-task.txt && commit -m "TA: a file the base lacks" ) >/dev/null
for _ in 1 2 3; do out="$(bash "$RUN" exec TA --base -- sh -c 'git rev-parse HEAD; test -e only-in-task.txt && echo has || echo lacks' 2>/dev/null)"; rc=$?; [ "$rc" = 75 ] || break; done
check "exec --base runs on the task's base commit, not its work" '[ "$(echo "$out" | sed -n 1p)" = "$(bash "$RUN" get tasks.TA.base_sha)" ] && [ "$(echo "$out" | sed -n 2p)" = lacks ] && [ -f "$wa/only-in-task.txt" ]'
check "exec --base keeps the job under the task and passes the exit code" 'bash "$RUN" exec TA --limit 30 --base -- sh -c "exit 5" 2>/dev/null; [ $? = 5 ]'
last_job() { local n=0 j; for j in .idleflow/runs/active/tasks/"$1"/jobs/*; do j="${j##*/}"; [ "$j" -gt "$n" ] && n="$j"; done; echo ".idleflow/runs/active/tasks/$1/jobs/$n/"; }
jb="$(last_job TA)"
check "a job records what ran and on which checkout" '[ "$(cat "${jb}checkout")" = "base $(bash "$RUN" get tasks.TA.base_sha)" ] && grep -qF "exit" "${jb}command" && bash "$RUN" exec TA -- true 2>/dev/null && [ "$(cat "$(last_job TA)checkout")" = task ]'
base_ta="$(git worktree list --porcelain | sed -n 's/^worktree \(.*_base-TA\)$/\1/p')"
check "guard: nothing in the base checkout can be edited" '[ "$(guard_rc "$base_ta/src/code.py" "$base_ta")" = "2" ] && [ "$(guard_rc "$base_ta/new.txt" "$base_ta")" = "2" ]'
echo stray > "$base_ta/stray-untracked"; first_file="$(git -C "$base_ta" ls-files | head -n1)"; echo edited >> "$base_ta/$first_file"
bash "$RUN" exec TA --base -- true >/dev/null 2>&1
check "an edited base checkout is made again before it runs" '[ -z "$(git -C "$base_ta" status --porcelain --untracked-files=no)" ] && [ ! -e "$base_ta/stray-untracked" ]'
echo 0000000 > .idleflow/runs/active/tasks/_base-TA/ready; touch "$base_ta/marker"
bash "$RUN" exec TA --base -- true >/dev/null 2>&1
check "a base checkout ready for another sha is made again" '[ ! -e "$base_ta/marker" ] && [ "$(cat .idleflow/runs/active/tasks/_base-TA/ready)" = "$(bash "$RUN" get tasks.TA.base_sha)" ]'
mkdir -p .idleflow/runs/active/tasks/_base-TA/lock && echo 999999 > .idleflow/runs/active/tasks/_base-TA/lock/pid
check "a lock left by a dead exec --base is taken over" 'bash "$RUN" exec TA --base -- true >/dev/null 2>&1 && [ ! -d .idleflow/runs/active/tasks/_base-TA/lock ]'
git worktree remove --force "$base_ta"; mkdir -p "$base_ta" && echo leftover > "$base_ta/leftover"
out="$(bash "$RUN" exec TA --base -- echo ran 2>&1)"; rc=$?
check "a base path that cannot be made again runs nothing" '[ "$rc" != 0 ] && ! echo "$out" | grep -qx ran && echo "$out" | grep -q "is not a clean checkout"'
rm "$base_ta/leftover"; rmdir "$base_ta"
bash "$RUN" exec TB --base -- true >/dev/null 2>&1
base_tb="$(git worktree list --porcelain | sed -n 's/^worktree \(.*_base-TB\)$/\1/p')"
bash "$RUN" exec TB -- sleep 60 >/dev/null 2> "$scratch/job.err"
job="$(sed -n 's/.*job \([0-9]*\) of TB is still running.*/\1/p' "$scratch/job.err")"
bash "$RUN" wt rm TB
check "wt rm removes the task's base checkout too" '[ -n "$base_tb" ] && [ ! -d "$base_tb" ]'
check "wt rm stops the task's jobs" '[ "$(cat .idleflow/runs/active/tasks/TB/jobs/$job/status)" = 143 ] && ! kill -0 "$(cat .idleflow/runs/active/tasks/TB/jobs/$job/pid)" 2>/dev/null'
rm -f .idleflow/idleflow.conf "$wa/child.pid"; [ ! -f "$scratch/conf.bak" ] || mv "$scratch/conf.bak" .idleflow/idleflow.conf
run_tmp_dir="$(bash "$RUN" exec TA -- sh -c 'echo "$TMPDIR"')"; run_tmp_dir="${run_tmp_dir%/TA}"
iso_id="$(bash "$RUN" get id)"
bash "$RUN" wt rm TA; bash "$RUN" wt rm TB; bash "$RUN" wt rm TC; bash "$RUN" wt rm TD; bash "$RUN" wt rm TE; bash "$RUN" wt rm TF; bash "$RUN" wt rm TG; bash "$RUN" finish done >/dev/null
check "finish removes the run's temp folders" '[ -n "$run_tmp_dir" ] && [ ! -e "$run_tmp_dir" ]'
check "finish gives back the run's port claims and no other" '! grep -qs "	$iso_id	" "$utmp"/ports/* && [ "$(cut -f2,3 "$utmp/ports/4402")" = "r1	T9" ]'

echo "--- a run started in a linked checkout"
hw="$d-human"; git worktree add -q -b human-work "$hw" 2>/dev/null
( cd "$hw" && bash "$RUN" new linked >/dev/null 2>&1 )
check "the run lives in the linked checkout it was started from" '[ -f "$hw/.idleflow/runs/active/run.json" ] && [ ! -e .idleflow/runs/active ] && [ "$(cd "$hw" && bash "$RUN" path lessons)" = "$(cd "$hw" && pwd)/.idleflow/lessons.md" ]'
( cd "$hw" && bash "$RUN" wt add TH > "$scratch/hwt" 2>/dev/null )
check "its task worktree finds that checkout, not the main one" '[ "$(cd "$(cat "$scratch/hwt")" && bash "$RUN" exec TH -- sh -c "echo \$MAIN" 2>/dev/null)" = "$(cd "$hw" && pwd)" ]'
( cd "$(cat "$scratch/hwt")" && git checkout -q --detach )
check "a task worktree on a detached HEAD still finds it" '[ "$(cd "$(cat "$scratch/hwt")" && bash "$RUN" exec TH -- sh -c "echo \$MAIN" 2>/dev/null)" = "$(cd "$hw" && pwd)" ]'
git worktree add -q -b "idleflow/no-such-run/TX" "$d-stray" 2>/dev/null
check "a branch named like a task's but of no active run is its own checkout" '[ "$(cd "$d-stray" && bash "$RUN" path lessons)" = "$(cd "$d-stray" && pwd)/.idleflow/lessons.md" ]'
( cd "$hw" && bash "$RUN" wt rm TH && bash "$RUN" finish "done" >/dev/null )
check "wt rm forgets the task worktree" '! git config --local --get-regexp "^idleflow\\.worktree\\..*/TH\\.checkout$" >/dev/null 2>&1'
git worktree remove --force "$d-stray"; git worktree remove --force "$hw"; git branch -q -D human-work "idleflow/no-such-run/TX"
rmdir "${hw}__wt" 2>/dev/null || true

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
if [ "$py_ok" = yes ]; then
  cp .idleflow/conventions.md "$d-conv.bak"
  printf 'gate: python3 -I show_m.py\n' >> .idleflow/conventions.md
  git add .idleflow/conventions.md && commit -q -m "python gate"; bash "$RUN" approve gate >/dev/null
  printf '%s\n' "import sys" "sys.path.insert(0, '.')" "import m" "print(m.x)" > show_m.py
  pin_m . 1; "${import_m[@]}" >/dev/null; pin_m . 2
  bash "$RUN" new python-gate >/dev/null 2>&1
  bash "$RUN" repo-gate main >/dev/null 2>&1
  check "the gate on main runs the source as it is, not an earlier command's bytecode" 'grep -qx 2 .idleflow/runs/active/repo-gate-main.log'
  bash "$RUN" finish "done" >/dev/null; unpin_m .; rm -f show_m.py
  cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"
fi

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
check "preview main is refused while tasks preview their worktrees" '! bash "$RUN" preview main start >/dev/null 2>&1 && [ ! -f .idleflow/runs/active/tasks/main/preview.pid ]'
printf 'preview_in: main\n' >> .idleflow/conventions.md
check "under preview_in: main a task preview is refused" '! bash "$RUN" preview T2 start >/dev/null 2>&1 && [ ! -f .idleflow/runs/active/tasks/T2/preview.pid ]'
sed -i.bak 's#^preview: .*#preview: pwd > "$IDLEFLOW_TMP/where"; sleep 30#' .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak
git add .idleflow/conventions.md && commit -q -m "preview from main"; bash "$RUN" approve preview >/dev/null
bash "$RUN" wt rm T2; bash "$RUN" finish done >/dev/null; bash "$RUN" new previewmain >/dev/null 2>&1
# another repo's live run holds PORT_BASE, so preview main takes the next port, under the owner main
printf '{"id":"r1","tasks":{"T9":{"port":4402},"T8":{"port":4400}}}\n' > "$o/.idleflow/runs/active/run.json"
printf '%s\tr1\tT8\n' "$o" > "$utmp/ports/4400"
out="$(bash "$RUN" preview main start 2>/dev/null)"; pid="$(cat .idleflow/runs/active/tasks/main/preview.pid 2>/dev/null)"; sleep 1
check "preview main claims a free port of its own" '[ "$(cut -f2,3 "$utmp/ports/4401" 2>/dev/null)" = "$(bash "$RUN" get id)	main" ] && [ "$(cut -f3 "$utmp/ports/4400")" = T8 ]'
check "a second preview main start reports the server already serving and claims nothing" 'again="$(bash "$RUN" preview main start 2>/dev/null)" && echo "$again" | grep -q "^preview main: serving at http://localhost:4173 (already running" && [ "$(cat .idleflow/runs/active/tasks/main/preview.pid)" = "$pid" ] && [ "$(grep -ls "	main$" "$utmp"/ports/* | wc -l | tr -d " ")" = 1 ]'
check "under preview_in: main the main checkout is served" 'echo "$out" | grep -q "^preview main: serving at http://localhost:4173" && kill -0 "$pid" 2>/dev/null && [ "$(cat "$utmp"/*/main/where 2>/dev/null)" = "$(pwd -P)" ]'
bash "$RUN" preview main stop >/dev/null; sleep 1
check "preview main stop ends it" '! kill -0 "$pid" 2>/dev/null'
check "preview main stop gives its port back and leaves other claims" '[ ! -e "$utmp/ports/4401" ] && [ "$(cut -f3 "$utmp/ports/4400")" = T8 ]'
bash "$RUN" preview main start >/dev/null 2>&1; pid2="$(cat .idleflow/runs/active/tasks/main/preview.pid 2>/dev/null)"; sleep 1
check "main and merged are not task ids" '! bash "$RUN" wt add main 2>/dev/null && ! bash "$RUN" wt add merged 2>/dev/null'
check "findings reads the browser check after merge" 'printf "### D1. A label   severity: minor\n" > .idleflow/runs/active/review/merged-design.md && [ "$(bash "$RUN" findings merged)" = "merged: D1. A label   severity: minor (review/merged-design.md)" ]'
bash "$RUN" finish "done" >/dev/null; sleep 1
check "finish stops a preview of main still serving and gives its port back" '[ -n "$pid2" ] && ! kill -0 "$pid2" 2>/dev/null && ! grep -qs "	main$" "$utmp"/ports/*'
cp "$d-conv.bak" .idleflow/conventions.md && rm -f "$d-conv.bak"; git add .idleflow/conventions.md && commit -q -m "restore conventions"

echo "--- plan extract"
bash "$RUN" new extract >/dev/null 2>&1
printf '%s\n' '# Plan: x' '## Goal' 'goal text' '## Stack & style constraints' 'mode: repo' '## Interfaces (serial, land first)' 'report(msg) prints "saved"' \
  '## Tasks' '### T1: first' 'owns: [a]' '### T10: tenth' 'owns: [b]' '### T2: second' 'owns: [c]' '## Merge order' 'T1, T2' > .idleflow/runs/active/plan.md
bash "$RUN" extract T1 > "$scratch/extract.txt"
check "extract gives the shared sections and the task's own" '[ "$(cat "$scratch/extract.txt")" = "$(printf "%s\n" "## Stack & style constraints" "mode: repo" "## Interfaces (serial, land first)" "report(msg) prints \"saved\"" "### T1: first" "owns: [a]")" ]'
check "extract leaves other tasks and sections out" '! grep -q "T10\|T2\|goal text\|Merge order" "$scratch/extract.txt"'
check "extract refuses a task the plan does not have" '! bash "$RUN" extract T3 2>/dev/null'
printf '%s\r\n' '## Interfaces' 'sig' '## Tasks' '### T1: first' '```md' '## not a section' '### T2: not a task' '```' 'after the fence' '### T2: second' > .idleflow/runs/active/plan.md
bash "$RUN" extract T1 > "$scratch/extract.txt"
check "extract reads a CRLF plan and keeps code fences in the task" '[ "$(cat "$scratch/extract.txt")" = "$(printf "%s\n" "## Interfaces" sig "### T1: first" "\`\`\`md" "## not a section" "### T2: not a task" "\`\`\`" "after the fence")" ]'
printf '%s\n' '## Tasks' '### T1: first' 'blocked_until: none   # nothing to wait for' '### T2: waits' 'depends_on: [T1]' 'blocked_until: revision — the error code CI prints for T1' '```' 'blocked_until: none' '```' '### T3: plain' 'owns: [c]' > .idleflow/runs/active/plan.md
check "plan-field reads a task's own field, not another's or a fenced one" '[ "$(bash "$RUN" plan-field T1 blocked_until)" = none ] && [ "$(bash "$RUN" plan-field T2 blocked_until)" = "revision — the error code CI prints for T1" ] && [ -z "$(bash "$RUN" plan-field T3 blocked_until)" ]'
out="$(bash "$RUN" wt add T2 2>&1)"; rc=$?
check "wt add refuses a task blocked until a revision, and creates nothing" '[ "$rc" = 8 ] && echo "$out" | grep -q "T2 is blocked until a revision (revision — the error code CI prints for T1)" && [ ! -d "$(dirname "$d")/$(basename "$d")__wt/T2" ] && ! git rev-parse -q --verify "refs/heads/idleflow/$(bash "$RUN" get id)/T2" >/dev/null && [ -z "$(bash "$RUN" get tasks.T2 2>/dev/null)" ]'
# a plan longer than a pipe holds, with the field near its top: the reader must still exit 0
{ printf '%s\n' '## Tasks' '### T1: first' 'blocked_until: revision — the code CI prints for #47   # waits on T0'; for _ in $(seq 1 3000); do printf 'notes: %s\n' "a line of text that makes the plan long enough to fill a pipe"; done; } > .idleflow/runs/active/plan.md
check "plan-field reads a long plan and keeps a # in the field's text" 'v="$(bash "$RUN" plan-field T1 blocked_until)" && [ "$v" = "revision — the code CI prints for #47" ]'
printf '%s\n' '## Tasks' '### T1: one' 'group: 1' 'owns:' '  - src/a/**   # its code' 'entry_points:' '  - src/a/x.py: run' '  - `src/b/y.py`: other' 'acceptance:' \
  '  - A1: `src/a/x.py` prints ok → verify: pytest tests/test_z.py::test_ok' '  - A2: .gitignore ignores build/, as https://example.com/a/b.html says; Order.currency stays' \
  '### T2: two' 'owns:' '  - .claude/**' '  - docs/**' 'acceptance:' '  - A1: `docs/guide.md` explains it' '```' '### T3: in a fence' 'owns:' '  - zzz' 'entry_points:' '  - q/r.py: f' '```' > .idleflow/runs/active/plan.md
bash "$RUN" plan-check > "$scratch/pc.txt" 2>&1; rc=$?
check "plan-check names each file a task names but does not own" '[ "$rc" = 1 ] && grep -qx "plan-check: T1 does not own src/b/y.py, which its entry point names; add it to T1.s owns: (or to shared_files when every task adds lines to it)" "$scratch/pc.txt" && grep -q "^plan-check: T1 does not own .gitignore, which its acceptance A2 names" "$scratch/pc.txt" && [ "$(grep -c "does not own" "$scratch/pc.txt")" = 2 ]'
check "plan-check names every protected file a wide glob owns" 'for p in .claude/settings.json .claude/settings.local.json .claude/agents/ .claude/hooks/; do grep -qx "plan-check: T2 owns the protected $p; protected files belong to no task" "$scratch/pc.txt" || exit 1; done && [ "$(grep -c "protected" "$scratch/pc.txt")" = 4 ] && ! grep -q "T3\|zzz" "$scratch/pc.txt"'
printf '%s\n' '## Tasks' '### T1: one' 'owns:' '  - src/a/**' '  - .gitignore' 'entry_points:' '  - src/a/x.py: run' 'acceptance:' '  - A1: `src/a/x.py` and .gitignore → verify: true' > .idleflow/runs/active/plan.md
check "plan-check passes a plan whose tasks own what they name" '[ "$(bash "$RUN" plan-check)" = "plan-check: every file each task names is in its owns: or shared_files, and no task owns a protected file" ]'
printf '%s\n' '## Tasks' \
  '### T1: inline lists and odd entry points' 'owns: [src/a/**, "tests/**"]' 'entry_points: [src/a/x.py: run]' 'entry_points:' '  - src/a/x.py:run' '  - src/a/y.py (new file)' '  - src/a/z.py::Klass' 'acceptance:' \
  '  - A1: writes $IDLEFLOW_TMP/report.json, /tmp/x.log and ~/.cache/a.json; serves localhost:4173/index.html' '  - A2: the report also' '    lands in docs/report.md → verify: true' '  - prints src\b\c.py' \
  '### T2: protected files, one at a time' 'owns:' '  - .claude/agents/reviewer.md' '  - .idleflow/conventions.md' '  - .claude/*/x.md' '  - .claude/skills/x/**' \
  '### T3: no named files' 'owns: [.claude/**, src/**]' 'acceptance:' '  - A1: → verify: true' > .idleflow/runs/active/plan.md
bash "$RUN" plan-check > "$scratch/pc.txt" 2>&1; rc=$?
check "plan-check reads inline lists, entry points with symbols and items that run on" '[ "$rc" = 1 ] && [ "$(grep -c "^plan-check: T1 " "$scratch/pc.txt")" = 2 ] && grep -q "^plan-check: T1 does not own docs/report.md, which its acceptance A2 names" "$scratch/pc.txt" && grep -q "^plan-check: T1 does not own src/b/c.py, which its acceptance (unnumbered) names" "$scratch/pc.txt"'
check "plan-check flags a protected file named inside its folder, and every task's wide glob" 'for l in "T2 owns the protected .claude/agents/" "T2 owns the protected .idleflow/" "T2 owns the protected .claude/hooks/" "T3 owns the protected .claude/settings.json" "T3 owns the protected .claude/agents/"; do grep -q "^plan-check: $l;" "$scratch/pc.txt" || exit 1; done && ! grep -q "T2 owns the protected .claude/settings" "$scratch/pc.txt"'
printf '%s\n' '## Tasks' '### T1 — one' 'owns: [.claude/**]' > .idleflow/runs/active/plan.md
check "plan-check refuses a task heading it cannot read, and a plan with no task" 'out="$(bash "$RUN" plan-check 2>&1)"; [ $? = 1 ] && echo "$out" | grep -q "### T1 — one\" is not a task heading" && echo "$out" | grep -q "has no task"'
printf '%s\n' '## Tasks' '### T1: one' 'owns: [.CLAUDE/Agents/**, src/**]' 'entry_points: [src/a.py]' > .idleflow/runs/active/plan.md
check "plan-check folds case only where the guard does" 'command -v cygpath >/dev/null 2>&1 || bash "$RUN" plan-check >/dev/null'
bash "$RUN" finish "done" >/dev/null

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
# idleflow's own templates carry generated blocks for the projects that use them; this repo fills none
# only when the plugin folder is its own repo, not a copy inside some other repo
if [ "$(git -C "$HERE/.." rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$HERE/.." && pwd -P)" ]; then
  check "idleflow's own repo keeps its templates' generated blocks empty" '( cd "$HERE/.." && bash scripts/run.sh docs --check >/dev/null 2>&1 )'
fi
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
echo "--- a worktree installs its own node_modules"
f="$(mktemp -d)"; ( cd "$f" && git init -q && mkdir -p .idleflow node_modules && printf 'mode: repo\nworktree_setup: unset\n' > .idleflow/conventions.md && printf '{}\n' > package.json && touch package-lock.json )
check "detect suggests the lockfile's install when main has node_modules" '(cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup: npm ci — the main checkout has node_modules/"'
rm -f "$f/package-lock.json"; touch "$f/pnpm-lock.yaml"
check "the install follows the package manager" '(cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup: pnpm install --frozen-lockfile —"'
rm -f "$f/pnpm-lock.yaml"; touch "$f/yarn.lock" "$f/.yarnrc.yml"
check "Yarn 2 and later install with --immutable" '(cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup: yarn install --immutable —"'
rm -f "$f/yarn.lock" "$f/.yarnrc.yml"
check "node_modules without a lockfile gets no proposal" '! (cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup"'
touch "$f/pnpm-lock.yaml"
mkdir -p "$f/.venv"; touch "$f/uv.lock"
check "a repo with both gets both installs" '(cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup: uv sync --frozen && pnpm install --frozen-lockfile — the main checkout has .venv/.*; the main checkout has node_modules/"'
rm -rf "$f/node_modules" "$f/.venv"
check "no node_modules in main, no suggestion" '! (cd "$f" && bash "$RUN" detect) | grep -q "^suggest worktree_setup"'
rm -rf "$f"
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
( cd "$f" && git checkout -q -- README.md && cp README.md notes..md && mkdir -p .git/x && cp README.md .git/x/y.md && cp README.md ./-x.md && sed -i.bak "s/^generated_docs: .*/generated_docs: notes..md .git\/x\/y.md -x.md/" .idleflow/conventions.md && rm -f .idleflow/conventions.md.bak )
out="$(cd "$f" && bash "$RUN" docs 2>"$d/gen.err")"
check "generated_docs judges each path by the one repo path rule" '[ "$out" = "docs: regenerated notes..md" ] && grep -q "skipped .\.git/x/y.md" "$d/gen.err" && grep -q "skipped .-x.md" "$d/gen.err" && ! grep -q "skipped .notes" "$d/gen.err"'
( cd "$f" && rm -f notes..md ./-x.md .git/x/y.md && rmdir .git/x && git checkout -q -- . )
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
check "reviewers list checks they could not decide, and the run routes them" 'grep -q "^unverified: <none" "$HERE/../agents/review-correct.md" && grep -q "^unverified: <none" "$HERE/../agents/review-design.md" && grep -q "\*\*Fixed, review again\*\*" "$HERE/../commands/feature.md" && grep -q "verify: ci <job name>" "$HERE/../agents/planner.md" && grep -q "verify: ci <job name>" "$HERE/../agents/implementer.md" && grep -q "verify: ci <job name>" "$HERE/../agents/implementer-hard.md" && grep -q "verify: ci <job name>" "$HERE/../agents/review-conform.md" && grep -q "blocked_on: environment:" "$HERE/../agents/implementer.md" && grep -q "\*\*Fixed, run it again\*\*" "$HERE/../commands/feature.md"'
check "both reviewers allow shared files" 'grep -q "top-level \`shared\` list" "$HERE/../agents/review-conform.md" && grep -q "top-level \`shared\` list" "$HERE/../agents/review-correct.md"'
check "research agents reach sources by endpoint" '[ -f "$HERE/../procedures/research-sources.md" ] && grep -q "GitHub API \`repos/<owner>/<repo>\`" "$HERE/../procedures/research-sources.md" && grep -q "curl -s -A \"research-client/1.0\" '"'"'https://api.github.com/<path>'"'"'" "$HERE/../procedures/research-sources.md" && ( for a in market-researcher stack-researcher library-scout; do grep -q "research-sources.md" "$HERE/../agents/$a.md" || exit 1; done ) && grep -q "research-sources.md" "$HERE/../commands/init.md" && [ "$(grep -o "research-sources.md" "$HERE/../procedures/repo-setup.md" | wc -l | tr -d " ")" -ge 2 ]'
check "no command labels the idleflow issues it opens" '! grep -rn --exclude=selftest.sh "add-label\|--label" "$HERE/../commands" "$HERE/../procedures" "$HERE/../agents" "$HERE/../templates" "$HERE" | grep -v "/commands/skills-feedback\.md:[0-9]*:.*add-label skill-request"'
check "the time log exists before the planner reads it" 'grep -q "copy \`templates/time-log.md\` if not" "$HERE/../commands/feature.md" && grep -q "copying \`templates/time-log.md\` if not" "$HERE/../commands/setup.md"'
check "human decisions reach the plan through the planner" 'grep -q "decisions.md" "$HERE/../agents/planner.md" && grep -q "Q<n>: answered" "$HERE/../agents/planner.md" && ! grep -q "apply the answer; continue" "$HERE/../commands/feature.md" && ! grep -q "write the answers into plan.md" "$HERE/../commands/feature.md" && grep -q "You never edit plan.md yourself" "$HERE/../commands/feature.md" && grep -q "Q1: <question> (default:" "$HERE/../templates/plan.md"'
check "attribution is one rule every commit writer gets" '( for a in implementer implementer-hard; do grep -q "in this repo this setting decides" "$HERE/../agents/$a.md" && grep -q "Claude-Session:" "$HERE/../agents/$a.md" || exit 1; done ) && grep -q "Claude-Session:" "$HERE/../agents/review-conform.md" && grep -q "Claude-Session:" "$HERE/../templates/CLAUDE.md" && [ "$(grep -c "co_author_claude: <value>" "$HERE/../commands/feature.md")" = 1 ] && grep -q "value of \`co_author_claude\` from \`CLAUDE.md\`" "$HERE/../commands/feature.md"'
check "the doc-keeper edits sentences, never whole files" '! grep -q "^tools:.*Write" "$HERE/../agents/doc-keeper.md" && grep -q "belongs to humans" "$HERE/../agents/doc-keeper.md" && grep -q "as it is on disk now" "$HERE/../templates/CLAUDE.md"'
check "agents run task commands through run.sh exec" '( for a in implementer implementer-hard review-correct; do grep -q "exec <task-id> -- <command>" "$HERE/../agents/$a.md" || exit 1; done ) && grep -q "IDLEFLOW_PORT" "$HERE/../agents/planner.md" && [ "$(grep -c "exec <task-id> -- <command>\|exec <id> -- <command>" "$HERE/../commands/feature.md")" = 2 ]'
check "the index limit counts only hand-written text" 'grep -q "outside generated blocks) stays under 80 lines" "$HERE/../agents/retro.md" && grep -q "the text outside its generated blocks stays under 80 lines" "$HERE/../commands/setup.md" && ! grep -q "Under 80 lines\.\|), under 80 lines," "$HERE/../agents/retro.md" "$HERE/../commands/setup.md"'
check "the planner writes prd.md only while it is the template" 'grep -q "Your prompt says whether \`prd.md\` is \`written\` or still the \`template\` R2 copied; \`greenfield\` is about code and never decides it" "$HERE/../agents/planner.md" && grep -q "When it is \`written\`, humans own it" "$HERE/../agents/planner.md" && ! grep -q "On a \*\*greenfield\*\* run you also \*write\* \`prd.md\`" "$HERE/../agents/planner.md" && grep -q "the paths of \`prd.md\` (with \`template\` when it is missing or its first line is still the template.s \`# <Project name> — product requirements\`, else \`written\`" "$HERE/../commands/feature.md" && grep -q "shows a change (the planner filled the template or applied a yes), run \`bash \"\$RUN\" snapshot\` first, before any worktree exists" "$HERE/../commands/feature.md" && head -n 1 "$HERE/../templates/prd.md" | grep -qx "# <Project name> — product requirements" && ! grep -q "planner fills \`prd.md\` on a greenfield run" "$HERE/../procedures/repo-setup.md"'
check "reviews record the checks they ran and the deviations they weighed" 'grep -q "^checks_run: <none (<why>) | one line each" "$HERE/../agents/review-correct.md" && grep -q "^deviations_weighed: <none | one line each" "$HERE/../agents/review-correct.md" && grep -q "record the judgement under \`deviations_weighed:\`" "$HERE/../agents/review-correct.md" && grep -q "^checks_run: <none (<why>) | one line each" "$HERE/../agents/review-design.md" && grep -q "\`deviations_weighed:\` is its judgement" "$HERE/../agents/retro.md"'
check "each issue form's title hint is the form ISSUES.md gives its kind" '( for k in bug workflow idea pushback; do form="$(grep -o "^| \`$k\` | \`$k: <[^\`]*>\` |\$" "$HERE/../ISSUES.md" | sed "s/^| \`$k\` | \`//; s/\` |\$//")"; [ -n "$form" ] && grep -qF "Title: \"$form\"" "$HERE/../.github/ISSUE_TEMPLATE/$k.md" || exit 1; done ) && ! grep -qE "^\| \`(idea|pushback)\` \| \`[a-z]+: <what is wrong" "$HERE/../ISSUES.md"'
check "the designer and design reviewer exist" '[ -f "$HERE/../agents/designer.md" ] && [ -f "$HERE/../agents/review-design.md" ] && grep -q "\"ui\"" "$HERE/../agents/classifier.md" && grep -q "^### 2c. Design" "$HERE/../commands/feature.md"'
check "requirements no screen shows reach the plan" 'grep -q "^- \`design.md\` at the output path: the screens for this run, \"Not on a screen\"" "$HERE/../agents/designer.md" && grep -q "Each line under \"Not on a screen\" becomes acceptance of the task that builds its surface" "$HERE/../agents/planner.md" && grep -q "listed under \"Not on a screen\"" "$HERE/../procedures/design.md"'
check "the design handbook carries the contrast rule" 'grep -q "4.5:1" "$HERE/../procedures/design.md" && grep -q "0.2126 R + 0.7152 G + 0.0722 B" "$HERE/../procedures/design-data.md"'
check "STEP_DESIGN is a setting" 'grep -q STEP_DESIGN "$HERE/conf.sh" && grep -q "^STEP_DESIGN=auto" "$HERE/../config/idleflow.conf"'
check "every command reads the talking rules" '[ -z "$(cd "$HERE/../commands" && grep -L "procedures/talking.md" *.md | grep -vx fix.md)" ]'
check "R3 chunks and concatenates"      'grep -q "stack-research-<n>.md" "$setup" && grep -q "\`cat\` them in order into \`.idleflow/runs/active/stack-research.md\` before step 3" "$setup"'

echo
if [ "$fails" -eq 0 ]; then echo "PASS ($(idleflow_rt_name))"; else echo "FAIL: $fails check(s)"; exit 1; fi
