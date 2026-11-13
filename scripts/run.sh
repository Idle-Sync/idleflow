#!/usr/bin/env bash
# Run lifecycle helper. Called by the orchestrator (the /idleflow:* commands).
# Everything is plain git + files so a run can be inspected or resumed by hand.
#
#   run.sh new <slug>                     -> creates .idleflow/runs/active/ for a new run, prints its <id>
#   run.sh wt add <task-id> [base-ref]    -> creates the task's worktree and branch, records its base sha, runs the approved
#                                            worktree_setup there (exit 6: setup failed, 7: not approved), prints the path
#   run.sh wt rm <task-id>                -> removes the worktree (keeps the branch); works with or without an active run
#   run.sh wt list                        -> lists idleflow worktrees
#   run.sh own <task-id> '<globs json>'   -> registers file ownership for the guard hook
#   run.sh skip <key>                     -> this run goes without a repo command (gate, gate_quick, worktree_setup, preview)
#   run.sh unowned <task-id>              -> paths the task's commits change (base..HEAD, what merges) that its globs,
#                                            .idleflow-run/** and shared_files do not cover; matched as the guard matches
#   run.sh exec <task-id> -- <command...> -> runs a command in the task's worktree with its own port (IDLEFLOW_PORT) and
#                                            its own temp folder (IDLEFLOW_TMP, TMPDIR), as a job; prints its output and exits
#                                            with its code, or exits 75 while it still runs after EXEC_WAIT_SECONDS
#   run.sh wait <task-id> <job>           -> waits for a job again, the same way
#   run.sh stop <task-id> <job>           -> ends a job and every process it started
#   run.sh get <key>                      -> prints a value from run.json (dotted keys ok)
#   run.sh set <key> <json>               -> sets a value in run.json (dotted keys ok)
#   run.sh inc <key> [n]                  -> adds n (default 1) to a counter in run.json
#   run.sh extract <task-id>              -> the task's plan extract: the plan's Stack & style constraints and Interfaces
#                                            sections, then the task's own ### <task-id>: section
#   run.sh report <task-id>               -> copies the task's .idleflow-run/result.md into the run dir as report.md, prints its path
#   run.sh gate <task-id> [limit]         -> runs diff-gate against the task's own base, writes tasks/<id>/gate.json, prints it;
#                                            refreshes the run's report.md when the worktree copy is newer
#   run.sh merge <task-id>                -> merges the task branch into the current branch (no-ff); exit 3 on conflict, 4 otherwise
#   run.sh ignore <pattern>               -> adds the pattern to the ignore file `ignore_in:` names, prints that file
#   run.sh snapshot                       -> commits the repo-level docs the orchestrator writes (conventions, CLAUDE.md, prd, ...)
#   run.sh finish [status]                -> logs the run to .idleflow/runs/log.jsonl, renames active/ to <id>/
#   run.sh loc                            -> prints hand-written code lines in the repo (DIFF_EXCLUDE applied)
#   run.sh conf                           -> prints resolved config values and the runtime in use
#   run.sh path <name>                    -> where a record lives here: conventions, lessons, progress, index, sessions, time-log, runs
#   run.sh migrate                        -> moves files a pre-.idleflow/ version kept under .claude/ and commits the move
#   run.sh doctor                         -> checks the repo's idleflow setup, one "ok|warn|fail|suggest <check>: <detail> | fix: <how>" line each
#   run.sh update-check                   -> prints one line when a newer idleflow is tagged on GitHub, nothing otherwise
#   run.sh session-name                   -> the path for a new session note (time-author, numbered or per-person, from conventions)
#   run.sh behind                         -> commits the upstream has that this branch lacks (fetches first; empty offline)
#   run.sh team-install                   -> recommends idleflow to teammates: .claude/settings.json plus a CLAUDE.md install note
#   run.sh docs [--check]                 -> regenerates the generated blocks in the repo's Markdown (--check: exit 1 if stale)
#   run.sh detect                         -> suggests Repo fit and Records settings from evidence in the repo (read-only)
#   run.sh repo-gate <base|main|task> [--quick] -> runs the approved gate (or gate_quick) there, times it; 1 failed, 7 unapproved
#   run.sh preview <task-id> start|stop   -> serves the app from that worktree for screenshots (approved command, localhost only)
#   run.sh commands                       -> the repo's commands (worktree_setup, gate) as committed, approved or unapproved here
#   run.sh approve <key>                  -> records this person's approval of that exact committed command (local git config)
#   run.sh agent <name>                   -> how to spawn that agent here: agent, model, extra instructions, contract
#   run.sh custom list                    -> this repo's customizations (.idleflow/idleflow.conf, agent instructions, replaced agents)
#   run.sh custom set <KEY> <value>       -> validates and writes one setting to .idleflow/idleflow.conf
#   run.sh custom unset <KEY>             -> removes it, so the plugin default applies again
#   run.sh custom report [ask|always|never] -> this person's consent to report customizations (local git config, never committed)
#   run.sh custom replace <agent>         -> copies the built-in agent to .claude/agents/idleflow-<agent>.md for the project to edit
#   run.sh custom merge <agent>           -> merges changes the built-in agent got since it was copied into the replacement
#   run.sh custom restore <agent>         -> back to the built-in agent: removes its replacement, instructions and model
#
# The active run lives in .idleflow/runs/active/ (a real directory, no symlinks, so it
# works on Windows). `finish` renames it to .idleflow/runs/<id>/. JSON work is done by
# scripts/idleflow.py or idleflow.js through rt.sh, whichever runtime is installed.
# Commits made here use the human's git identity; the "idleflow" identity is a fallback
# for machines with none configured.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/rt.sh"
# shellcheck source=/dev/null
source "$HERE/conf.sh"

REPO="$(git rev-parse --show-toplevel)"
# Called from inside a linked worktree (an agent's `run.sh exec`), the run still lives in the main
# checkout. git itself names it: the common git dir's parent. No file in the checkout is trusted
# for this, since a committed one could point anywhere.
_git_dir="$(git rev-parse --path-format=absolute --git-dir)"; _common="$(git rev-parse --path-format=absolute --git-common-dir)"
if [ "$_git_dir" != "$_common" ] && [ "$(basename "$_common")" = .git ]; then REPO="$(dirname "$_common")"; fi
idleflow_load_conf "$REPO"
IDLE="$REPO/.idleflow"
CONVENTIONS="$IDLE/conventions.md"
RUNS="$IDLE/runs"
ACTIVE="$RUNS/active"
SUFFIX="${WORKTREE_SUFFIX:-__wt}"
G=(git -C "$REPO")

IDENTITY=()
if ! git config user.email >/dev/null 2>&1; then IDENTITY=(-c user.name=idleflow -c user.email=idleflow@local); fi
gcommit() { "${G[@]}" ${IDENTITY[@]+"${IDENTITY[@]}"} commit -q "$@"; }

# Paths handed to agents or written to JSON are native (D:/x on Windows, unchanged elsewhere).
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
# A bash string as a JSON string literal (backslash and double quote escaped).
json_str() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

plugin_version() { idleflow_rt get "$HERE/../.claude-plugin/plugin.json" version 2>/dev/null || echo unknown; }

# the title in the plan's "### <task-id>: <title>" heading, empty when there is none
plan_title() { # plan_title <task-id>
  [ -f "$ACTIVE/plan.md" ] || return 0
  H="### $1:" awk 'index($0, ENVIRON["H"]) == 1 { print substr($0, length(ENVIRON["H"]) + 1); exit }' "$ACTIVE/plan.md" | tr -d '\r'
}

active_id() {
  [ -f "$ACTIVE/run.json" ] || { echo "no active run (run.sh new <slug> first)" >&2; exit 1; }
  local id started_on
  id="$(idleflow_rt get "$ACTIVE/run.json" id)"
  [ -n "$id" ] && [ "$id" != "null" ] || { echo "active run.json has no id; fix or delete .idleflow/runs/active" >&2; exit 1; }
  # a plugin reload mid-run hands later agents a new version while this run keeps its old scripts
  started_on="$(idleflow_rt get "$ACTIVE/run.json" plugin_version 2>/dev/null || echo unknown)"
  if [ "$started_on" != unknown ] && [ "$started_on" != "$(plugin_version)" ]; then
    echo "WARNING: run $id started on idleflow $started_on but this is idleflow $(plugin_version); agents and scripts may disagree. Finish the run, then restart Claude Code." >&2
  fi
  echo "$id"
}

# A path from the conventions that stays inside the repo's files: not absolute (/, ~, a drive letter),
# no `..` folder, nothing under `.git` (hooks there run code), no leading `-` (a command would read it
# as an option), and only characters that need no quoting. Prints it without a leading ./ or a
# trailing /, or fails. Other dot folders such as .idleflow/ and .github/ are fine.
# repo_relative_path <path> [extra allowed characters, e.g. '*' for globs]
repo_relative_path() {
  local p="${1#./}" extra="${2:-}" part
  p="${p%/}"
  [ -n "$p" ] || return 1
  case "$p" in /*|'~'*|-*|[A-Za-z]:*) return 1;; esac
  [[ "$p" =~ ^[A-Za-z0-9_./${extra}-]+$ ]] || return 1
  local -a parts
  IFS=/ read -ra parts <<< "$p"
  for part in "${parts[@]}"; do
    case "$(printf '%s' "$part" | tr '[:upper:]' '[:lower:]')" in ..|.git|.git.*) return 1;; esac
  done
  echo "$p"
}
# A repo can keep its records where it already keeps them (conventions "Records"). A value must be
# a plain relative path inside the repo; anything else falls back to the default, with a warning.
record_path() { # record_path <conventions key> <default>
  local v; v="$(conventions_value "$1")"
  case "$v" in ""|unset) echo "$2"; return;; esac
  repo_relative_path "$v" && return
  echo "[idleflow] $1: '$v' is not a relative path inside the repo; using $2" >&2
  echo "$2"
}
lessons_rel() {
  case "$(conventions_value lessons_in)" in
    docs) echo docs/lessons.md;;
    *.md) record_path lessons_in .idleflow/lessons.md;;
    *) echo .idleflow/lessons.md;;
  esac
}
lessons_path() { echo "$REPO/$(lessons_rel)"; }
progress_rel() { record_path progress_file progress.md; }
index_rel() { record_path index_file index.md; }
sessions_rel() { record_path sessions_dir docs/sessions; }
time_log_rel() { record_path time_log .idleflow/time-log.md; }
# Files every task may add its own lines to (a changelog, an index the repo's checks require rows
# in); parallel tasks cannot own one file, so these sit outside ownership and merge by union.
shared_files() {
  local v f; v="$(conventions_value shared_files)"
  case "$v" in ""|unset|none) return 0;; esac
  for f in $(set -f; echo $v); do
    repo_relative_path "$f" '*' || echo "[idleflow] shared_files: skipped '$f'" >&2
  done
}

# Older versions kept idleflow's files under .claude/; these rewrite mentions of the old paths.
rewrite_old_paths() {
  sed -e 's#\.claude/conventions\.md#.idleflow/conventions.md#g' -e 's#\.claude/lessons\.md#.idleflow/lessons.md#g' \
      -e 's#\.claude/runs#.idleflow/runs#g' -e 's#\.claude-run/#.idleflow-run/#g'
}
rewrite_file() { # keeps the file's mode, which mv over a temp file would not
  local f="$1" tmp="$1.idleflow-tmp"
  rewrite_old_paths < "$f" > "$tmp" && cat "$tmp" > "$f" && rm -f "$tmp"
}

UPDATE_CMD="claude plugin marketplace update idlesync && claude plugin update idleflow@idlesync"

# Releases are the v<semver> tags on GitHub. Empty when offline or when IDLEFLOW_NO_UPDATE_CHECK is set.
newest_release() {
  [ -n "${IDLEFLOW_NO_UPDATE_CHECK:-}" ] && return 0
  GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs https://github.com/Idle-Sync/idleflow 'v*' 2>/dev/null \
    | sed -n 's#.*refs/tags/v\([0-9]*\.[0-9]*\.[0-9]*\)$#\1#p' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1
}
version_newer() { # version_newer <installed> <candidate>: true when candidate is the higher semver
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$2" ]
}

# A missing conventions file or key reads as empty; under set -e a failing lookup must not end the script.
conventions_value() { { sed -n "s/^$1: *//p" "$CONVENTIONS" 2>/dev/null || true; } | head -1 | tr -d '\r' | sed 's/ *$//'; }
check_line() { printf '%s %s: %s%s\n' "$1" "$2" "$3" "${4:+ | fix: $4}"; }

PROJECT_CONF="$IDLE/idleflow.conf"
# Consent to post customization reports from one's own GitHub account is personal, so it lives in
# this clone's git config, never in a committed file a teammate could set for everyone.
report_preference() {
  local v; v="$("${G[@]}" config --local --get idleflow.reportCustomizations 2>/dev/null || true)"
  case "$v" in always|never) echo "$v";; *) echo ask;; esac
}
agent_key() { echo "$1" | tr 'a-z-' 'A-Z_'; }
known_agent() { [ -n "$1" ] && [ -f "$HERE/../agents/$1.md" ] || { echo "unknown agent '$1'; one of: $(cd "$HERE/../agents" && ls -- *.md | sed 's/\.md$//' | tr '\n' ' ')" >&2; exit 1; }; }
replacement_path() { echo "$REPO/.claude/agents/idleflow-$1.md"; }
# The built-in prompt as a replacement starts from it: only the frontmatter name differs, so
# a three-way merge sees the project's edits and nothing else.
renamed_agent() { sed "1,/^---\$/s/^name: $1\$/name: idleflow-$1/" "$HERE/../agents/$1.md"; }
set_project_conf() { # set_project_conf <KEY> [value]: no value removes the key
  local tmp="$PROJECT_CONF.tmp"
  mkdir -p "$IDLE"
  [ -f "$PROJECT_CONF" ] || printf '# This repo'"'"'s idleflow settings, written by /idleflow:customize. Committed; read by scripts/conf.sh.\n' > "$PROJECT_CONF"
  grep -v "^$1=" "$PROJECT_CONF" > "$tmp" || true
  [ -z "${2:-}" ] || echo "$1=$2" >> "$tmp"
  cat "$tmp" > "$PROJECT_CONF" && rm -f "$tmp"
}

# Several people (or parallel tasks) add to these files at the same spot (new lessons at the end,
# new progress entries at the top); git's built-in union driver keeps both sides instead of conflicting.
union_merge_files() { { lessons_rel; progress_rel; echo .idleflow/suggestions.md; time_log_rel; shared_files; } 2>/dev/null | awk '!seen[$0]++'; }
# Only files git tracks ever merge, so an ignored record (kept local) needs no rule.
union_merge_targets() {
  local f
  while IFS= read -r f; do "${G[@]}" check-ignore -q --no-index -- "$f" || echo "$f"; done < <(union_merge_files)
}
# idleflow's merge rules go where its ignore rules go (ignore_in): the committed .gitattributes,
# or .git/info/attributes when nothing about idleflow may appear in a committed file.
attributes_file() {
  if grep -q '^ignore_in: *gitignore' "$CONVENTIONS" 2>/dev/null; then
    echo "$REPO/.gitattributes"
  else
    local f; f="$(exclude_file)"; echo "${f%/exclude}/attributes"
  fi
}
ensure_union_merge() {
  local f attrs; attrs="$(attributes_file)"
  while IFS= read -r f; do add_ignore "$attrs" "$f merge=union"; done < <(union_merge_targets)
}

# Who is writing, for per-person session folders: idleflow.person in git config (set it to name the
# folder), else the GitHub login, looked up once and remembered locally, else the git name.
person_id() {
  local p
  p="${IDLEFLOW_PERSON:-$(git config idleflow.person 2>/dev/null || true)}"
  if [ -z "$p" ] && command -v gh >/dev/null 2>&1; then
    p="$(GH_PROMPT_DISABLED=1 gh api user --jq .login 2>/dev/null || true)"
    [ -n "$p" ] && "${G[@]}" config --local idleflow.person "$p"
  fi
  [ -n "$p" ] || p="$(author_slug)"
  echo "$p" | tr -cs 'A-Za-z0-9_.-' '-' | sed 's/^-//;s/-$//' | cut -c1-39
}
author_slug() { git config user.name 2>/dev/null | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-20; }

# --- generated doc blocks: text between `<!-- idleflow:generated NAME -->` and `<!-- idleflow:end -->`.
# Each generator reads only committed files and git history, so every clone writes the same bytes.
DOC_START_RE='^<!-- idleflow:generated ([a-z-]+) -->$'
DOC_END='<!-- idleflow:end -->'
md_code() { printf '%s' "$1" | tr '`' "'"; }
# The Markdown files run.sh docs keeps, one per line. `generated_docs:` in conventions names them
# (`none` for no file); unset means every tracked Markdown file with a block, plus idleflow's own
# records (the index, the progress file, CLAUDE.md), which a repo may keep out of git.
generated_doc_files() {
  local v f list
  v="$(conventions_value generated_docs)"
  case "$v" in
    none) return 0;;
    ""|unset) { "${G[@]}" grep -l -e '<!-- idleflow:generated ' -- '*.md' 2>/dev/null || true; printf '%s\n' "$(index_rel)" "$(progress_rel)" CLAUDE.md; };;
    *) read -ra list <<< "$v"
       for f in "${list[@]}"; do
         case "$f" in /*|*..*) echo "[idleflow] generated_docs: skipped '$f' (not a path inside the repo)" >&2;; *) echo "$f";; esac
       done;;
  esac | LC_ALL=C sort -u | while IFS= read -r f; do
    [ -f "$REPO/$f" ] && grep -q '<!-- idleflow:generated ' "$REPO/$f" && echo "$f"
  done
  return 0
}

gen_files() { # $1: the block's current text; descriptions written there are kept
  local e desc
  while IFS= read -r e; do
    desc="$(grep -F -- "- \`$e\` — " "$1" 2>/dev/null | head -1 | sed "s/^- \`[^\`]*\` — //" || true)"
    echo "- \`$e\` — ${desc:-(describe)}"
  done < <({ "${G[@]}" ls-files -z || true; } | while IFS= read -r -d '' e; do
             case "$e" in */*) printf '%s\n' "${e%%/*}/";; *) printf '%s\n' "$e";; esac
           done | LC_ALL=C sort -u)
}
gen_commands() {
  local pm=npm k v c
  [ -f pnpm-lock.yaml ] && pm=pnpm; [ -f yarn.lock ] && pm=yarn; { [ -f bun.lock ] || [ -f bun.lockb ]; } && pm=bun
  # first the install a fresh clone runs, as its lockfile pins it
  if [ -f pnpm-lock.yaml ]; then echo "- \`pnpm install --frozen-lockfile\` — install (pnpm-lock.yaml)"
  elif [ -f yarn.lock ]; then echo "- \`yarn install --frozen-lockfile\` — install (yarn.lock)"
  elif [ -f bun.lock ] || [ -f bun.lockb ]; then echo "- \`bun install --frozen-lockfile\` — install (bun lockfile)"
  elif [ -f package-lock.json ]; then echo "- \`npm ci\` — install (package-lock.json)"; fi
  if [ -f uv.lock ]; then echo "- \`uv sync --frozen\` — install (uv.lock)"
  elif [ -f poetry.lock ]; then echo "- \`poetry install\` — install (poetry.lock)"
  elif [ -f requirements.txt ]; then echo "- \`pip install -r requirements.txt\` — install (requirements.txt)"; fi
  [ -f Cargo.lock ] && echo "- \`cargo build --locked\` — install and build (Cargo.lock)"
  [ -f go.sum ] && echo "- \`go mod download\` — install (go.sum)"
  if [ -f package.json ]; then
    while IFS=$'\t' read -r k v; do
      case "$pm" in npm|bun) c="$pm run $k";; *) c="$pm $k";; esac
      echo "- \`$c\` — runs \`$(md_code "$v")\`"
    done < <(idleflow_rt entries package.json scripts | LC_ALL=C sort)
  fi
  [ -f Makefile ] && { grep -E '^[A-Za-z0-9][A-Za-z0-9_-]*:([^=]|$)' Makefile || true; } | cut -d: -f1 | LC_ALL=C sort -u | sed 's/.*/- `make &`/'
  [ -f justfile ] && { grep -E '^[A-Za-z0-9][A-Za-z0-9_-]*( [^:=]*)?:([^=]|$)' justfile || true; } | sed 's/[ :].*//' | LC_ALL=C sort -u | sed 's/.*/- `just &`/'
  [ -f pyproject.toml ] && awk '/^\[/{s=($0=="[project.scripts]")} s && /^[A-Za-z0-9_.-]+ *=/{sub(/ *=.*/,""); print "- `" $0 "` — console script from pyproject.toml"}' pyproject.toml | LC_ALL=C sort
  return 0
}
gen_milestones() {
  local progress; progress="$(progress_rel)"
  [ -f "$progress" ] || return 0
  awk '/^## /{ m = ($0 ~ /^## Milestones/); next }
       m && /^### /{ if (title != "") print "- " title ": " d "/" t; title = $0; sub(/^### +/, "", title); sub(/ — .*/, "", title); d = 0; t = 0; next }
       m && /^- \[x\]/{ d++; t++ } m && /^- \[ \]/{ t++ }
       END{ if (title != "") print "- " title ": " d "/" t }' "$progress"
}
gen_dependencies() {
  local k v
  if [ -f package.json ]; then
    while IFS=$'\t' read -r k v; do echo "- \`$k\` $v — package.json"; done < <(idleflow_rt entries package.json dependencies | LC_ALL=C sort)
    while IFS=$'\t' read -r k v; do echo "- \`$k\` $v — package.json (dev)"; done < <(idleflow_rt entries package.json devDependencies | LC_ALL=C sort)
  fi
  [ -f requirements.txt ] && { grep -vE '^[[:space:]]*(#|-|$)' requirements.txt || true; } | sed 's/[[:space:]]*#.*//' | LC_ALL=C sort | sed 's/.*/- `&` — requirements.txt/'
  [ -f pyproject.toml ] && awk '/^dependencies *= *\[/{ l = 1; next } l && /\]/{ l = 0 } l { gsub(/[",]/, ""); gsub(/^ +| +$/, ""); if ($0 != "") print "- `" $0 "` — pyproject.toml" }' pyproject.toml | LC_ALL=C sort
  [ -f Cargo.toml ] && awk '/^\[/{ s = ($0 == "[dependencies]") } s && /^[A-Za-z0-9_-]+ *=/{ n = $0; sub(/ *=.*/, "", n); print "- `" n "` — Cargo.toml" }' Cargo.toml | LC_ALL=C sort
  [ -f go.mod ] && awk '/^require \(/{ r = 1; next } r && /^\)/{ r = 0 } r && NF >= 2 { print "- `" $1 "` " $2 " — go.mod" } /^require [^(]/{ print "- `" $2 "` " $3 " — go.mod" }' go.mod | LC_ALL=C sort
  return 0
}
gen_runs() { # the last ten idleflow runs merged here, newest first: merge commits with a Run trailer,
  # plus older merges whose subject held the run id
  { "${G[@]}" log --merges --date=short --format='%ad%x09%an%x09%s%x09%(trailers:key=Run,valueonly,separator=)' || true; } |
    awk -F'\t' '$4 != "" || $3 ~ /^idleflow: merge / || $3 ~ /^chore\(idleflow\): merge task /' |
    awk -F'\t' '{ id = $4; if (id == "" && match($3, /\(([^)]+)\)$/)) id = substr($3, RSTART + 1, RLENGTH - 2)
                  if (id == "") next; if (!(id in n)) { order[++k] = id; when[id] = $1; who[id] = $2 } n[id]++ }
                END { for (i = 1; i <= k && i <= 10; i++) { id = order[i]; print "- " when[id] " " who[id] ": run `" id "`, " n[id] " task(s) merged" } }'
}
gen_settings() {
  local k v
  for k in mode docs lessons_in progress_file index_file index_rewrite sessions_dir session_names time_log shared_files generated_docs \
           worktrees_in worktree_setup commit_format gate gate_quick gate_runs preview preview_url language tone; do
    v="$(conventions_value "$k")"; [ -n "$v" ] && echo "- \`$k\`: $(md_code "$v")"
  done
  [ -f "$PROJECT_CONF" ] && bash "$0" custom list 2>/dev/null | grep -v '^instructions:\|^replaced:' | sed 's/^/- `/; s/=/`: /'
  return 0
}

# A task id names a folder (its worktree, tasks/<id>/) and a branch (idleflow/<run>/<id>), so it is
# one path segment that git also takes in a ref name: no / \ : * ? " < > | ~ ^ [ ] @ { } and no
# space or control character, no "..", not ending in "." or ".lock", and not starting with "." or
# "-" or "_" (idleflow's own worktrees, such as _gate-base, start with "_"), and not a name Windows
# keeps for a device (CON, NUL, COM1, ...). Every subcommand that takes a task id checks it here
# before building anything from it.
check_task_id() { # check_task_id <id>
  local t="$1" bad='[]/\\:*?"<>|~^[@{}[:space:][:cntrl:]]' device='^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$'
  if [ -z "$t" ] || [[ "$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')" =~ $device ]] || [[ "$t" =~ $bad ]] || [[ "$t" == *..* ]] || [[ "$t" == [._-]* ]] || [[ "$t" == *. ]] || [[ "$t" == *.lock ]]; then
    echo "not a task id: '$t' (one name such as T1, with no path or git ref characters)" >&2
    exit 1
  fi
}

# Sibling by default (<repo>__wt/<task>); `worktrees_in: inside` keeps them in an ignored folder
# inside the repo, for projects that forbid writing outside their own folder.
wt_path() {
  if [ "$(conventions_value worktrees_in)" = inside ]; then echo "$IDLE/worktrees/$1"; else echo "${REPO}${SUFFIX}/$1"; fi
}

# Repo commands come from whoever pushed the repo: they run only as committed at HEAD, and only once
# this person approved that exact text (a hash in local git config; any change asks again).
REPO_COMMANDS="worktree_setup gate gate_quick preview"
repo_command() { # the committed value of a command key, empty when unset
  local v
  v="$({ "${G[@]}" show "HEAD:.idleflow/conventions.md" 2>/dev/null || true; } | sed -n "s/^$1: *//p" | head -1 | tr -d '\r' | sed 's/ *$//')"
  case "$v" in unset|none) v="";; esac
  echo "$v"
}
command_hash() { printf '%s' "$1" | git hash-object --stdin; }
approval_key() { echo "idleflow.approved-$(echo "$1" | tr '_' '-')"; }   # git config names allow no underscore
command_approved() { # command_approved <key> <command>
  [ "$("${G[@]}" config --local --get "$(approval_key "$1")" 2>/dev/null || true)" = "$(command_hash "$2")" ]
}

# A worktree isolates files. What a task's commands share at run time is handled here: each task
# gets its own port and temp folder.
task_port() { idleflow_rt get "$ACTIVE/run.json" "tasks.$1.port" 2>/dev/null || true; }
task_tmp() { echo "$ACTIVE/tasks/$1/tmp"; }
# The lowest PORT_BASE + n no other task of this run holds; a task keeps its port when re-added.
allocate_port() { # allocate_port <task-id>
  local mine used n=0; mine="$(task_port "$1")"
  case "$mine" in ""|null) ;; *) echo "$mine"; return;; esac
  used="$(idleflow_rt entries "$ACTIVE/run.json" tasks 2>/dev/null | sed -n 's/.*"port":\([0-9]*\).*/\1/p')"
  while printf '%s\n' "$used" | grep -qx "$(( ${PORT_BASE:-4400} + n ))"; do n=$((n + 1)); done
  echo $(( ${PORT_BASE:-4400} + n ))
}
# The repo's own commands (setup, gate, tests, preview) run as they would for a person or in CI.
# Tools change behaviour when they see they run under an agent (Astro's preview detaches, for one),
# so the variables that say so are removed from every repo command's environment here.
AGENT_MARKERS=(CLAUDECODE CLAUDE_CODE CLAUDE_CODE_ENTRYPOINT AI_AGENT)
without_agent_markers() { unset "${AGENT_MARKERS[@]}"; }

# Runs a command for a task: in its worktree, with its port and temp folder.
in_task() { # in_task <task-id> <dir> <command...>
  local tid="$1" dir="$2" port tmp rc=0; shift 2
  port="$(task_port "$tid")"; tmp="$(task_tmp "$tid")"; mkdir -p "$tmp"
  # the caller decides what a failure means; errexit is left as the caller set it
  (cd "$dir" && without_agent_markers && MAIN="$REPO" IDLEFLOW_TASK="$tid" IDLEFLOW_PORT="$port" IDLEFLOW_TMP="$tmp" TMPDIR="$tmp" "$@") || rc=$?
  return "$rc"
}

# A task's commands run as jobs: each in its own session, its output in tasks/<id>/jobs/<n>/log and
# its exit code in .../status when it ends. exec and wait return within EXEC_WAIT_SECONDS, below the
# point where Claude Code moves a subagent's Bash command to the background, where the agent could
# no longer wait for it or stop it; a job still running is waited on again or stopped by number.
job_dir() { echo "$ACTIVE/tasks/$1/jobs/$2"; }
# The job's pid is written by its own shell ($$), so it is one bash's kill understands everywhere
# (on Git Bash a runtime's pid is a Windows one). The job leads its own process group. Once the
# command has ended and no process of the group is left, the job is marked ended and never
# signalled again: its pid may since belong to someone else.
job_pid() { cat "$1/pid" 2>/dev/null || true; }
group_alive() { # group_alive <job dir>
  local pid; pid="$(job_pid "$1")"
  [ -n "$pid" ] && { kill -0 -- "-$pid" 2>/dev/null || kill -0 "$pid" 2>/dev/null; }
}
job_ended() { # job_ended <job dir>: the command ended and nothing of it is left
  [ -f "$1/ended" ] && return 0
  if [ -f "$1/status" ] && ! group_alive "$1"; then : > "$1/ended"; return 0; fi
  return 1
}
stop_job() { # stop_job <job dir>: TERM to the whole group, KILL after 5 s; 143 if the command had not ended
  local pid n=0
  job_ended "$1" && return 0
  pid="$(job_pid "$1")"; [ -n "$pid" ] || return 0
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  while group_alive "$1" && [ "$n" -lt 25 ]; do sleep 0.2; n=$((n + 1)); done
  if group_alive "$1"; then kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true; sleep 0.5; fi
  if group_alive "$1"; then echo "[idleflow] job in $(native_path "$1") still has processes after KILL" >&2; return 1; fi
  [ -f "$1/status" ] || { echo 143 > "$1/status.tmp" && mv "$1/status.tmp" "$1/status"; }
  : > "$1/ended"
}
await_job() { # await_job <task-id> <job>: the command's output and exit code, or 75 while it runs
  local d end n=0; d="$(job_dir "$1" "$2")"
  [ -d "$d" ] || { echo "no job $2 for task $1" >&2; exit 1; }
  while [ ! -f "$d/pid" ] && [ ! -f "$d/status" ] && [ "$n" -lt 50 ]; do sleep 0.1; n=$((n + 1)); done
  end=$(( $(date +%s) + ${EXEC_WAIT_SECONDS:-100} ))
  while [ ! -f "$d/status" ] && [ "$(date +%s)" -lt "$end" ]; do
    if ! group_alive "$d"; then
      sleep 0.2; [ -f "$d/status" ] || { echo 1 > "$d/status.tmp" && mv "$d/status.tmp" "$d/status"; echo "[idleflow] job $2 of $1 ended without an exit code" >&2; }
      break
    fi
    sleep 0.2
  done
  if [ -f "$d/status" ]; then
    cat "$d/log"
    # the command is over; a process it left behind (a server it started) is said, not waited for
    job_ended "$d" || echo "[idleflow] job $2 of $1 ended, but processes it started still run; end them with: bash \"$0\" stop $1 $2" >&2
    exit "$(cat "$d/status")"
  fi
  tail -n 20 "$d/log"
  echo "[idleflow] job $2 of $1 is still running (log: $(native_path "$d/log")). Wait for it: bash \"$0\" wait $1 $2. End it: bash \"$0\" stop $1 $2. Do not start it again while it runs." >&2
  exit 75
}

# The repo's own preparation for a fresh worktree (link shared folders, copy fixtures).
run_worktree_setup() { # run_worktree_setup <task-id> <worktree>
  local cmd log
  cmd="$(idleflow_rt get "$ACTIVE/run.json" worktree_setup 2>/dev/null || true)"
  case "$cmd" in ""|null) return 0;; esac
  if ! command_approved worktree_setup "$cmd"; then
    echo "worktree_setup is not approved on this clone; nothing ran. The command is: $cmd" >&2
    echo "show it to the human; on a yes: run.sh approve worktree_setup" >&2
    exit 7
  fi
  log="$ACTIVE/tasks/$1/setup.log"
  echo "worktree setup ($1): $cmd" >&2
  if ! (cd "$2" && without_agent_markers && MAIN="$REPO" WORKTREE="$2" bash -c "$cmd") > "$log" 2>&1; then
    echo "worktree setup failed for $1 (full output: $(native_path "$log")):" >&2
    tail -20 "$log" >&2
    exit 6
  fi
  local changed
  changed="$(git -C "$2" status --porcelain --untracked-files=no)"
  if [ -n "$changed" ]; then
    git -C "$2" checkout -q -- .
    echo "worktree setup for $1 changed tracked files, so they were restored and the worktree is not ready:" >&2
    echo "$changed" >&2
    exit 6
  fi
  # A dependency folder linked to the main checkout's is shared, not borrowed: an install in the
  # worktree (npm ci, pip) rewrites or empties the main checkout's copy, and Python's editable
  # install there runs the main checkout's code. The worktree builds its own instead.
  local dep main_real target
  main_real="$(cd -P "$REPO" && pwd)"
  for dep in node_modules .venv venv; do
    [ -L "$2/$dep" ] || continue
    target="$(cd -P "$2/$dep" 2>/dev/null && pwd)" || target=""
    case "$target" in "$main_real"|"$main_real"/*)
      rm -f "$2/$dep"
      echo "worktree setup for $1 linked $dep to the main checkout's ($target); the link was removed and the worktree is not ready." >&2
      echo "an install in the worktree would rewrite the main checkout's $dep; make worktree_setup build the worktree's own (npm ci, uv sync, python3 -m venv)" >&2
      exit 6;;
    esac
  done
}

exclude_file() {
  local f
  f="$("${G[@]}" rev-parse --git-common-dir)/info/exclude"
  case "$f" in /*|?:*) ;; *) f="$REPO/$f";; esac
  echo "$f"
}

# idleflow's own ignore rules stay clone-local until the human picks `ignore_in: gitignore`,
# so nothing about the tooling reaches a committed file unasked.
ignore_file() {
  if grep -q '^ignore_in: *gitignore' "$CONVENTIONS" 2>/dev/null; then
    echo "$REPO/.gitignore"
  else
    exclude_file
  fi
}

add_ignore() { # add_ignore <file> <pattern>
  local f="$1" pat="$2"
  [ -f "$f" ] && tr -d '\r' < "$f" | grep -qxF -- "$pat" && return 0
  mkdir -p "$(dirname "$f")"
  # a file without a final newline would otherwise glue our line onto its last entry
  [ ! -s "$f" ] || [ -z "$(tail -c1 "$f")" ] || echo >> "$f"
  echo "$pat" >> "$f"
}

# Build the DIFF_EXCLUDE pathspec list into EXCL[].
build_excl() {
  EXCL=()
  while IFS= read -r pat; do [ -z "$pat" ] && continue; EXCL+=(":(glob,exclude)$pat"); done <<< "${DIFF_EXCLUDE:-}"
}

# Move a leftover active/ aside under its own id so a new run can start.
park_active() {
  [ -d "$ACTIVE" ] || return 0
  local old=""
  [ -f "$ACTIVE/run.json" ] && old="$(idleflow_rt get "$ACTIVE/run.json" id 2>/dev/null || true)"
  [ -n "$old" ] && [ "$old" != "null" ] || old="abandoned-$(date +%Y%m%d-%H%M%S)"
  if [ -f "$ACTIVE/run.json" ]; then
    idleflow_rt set "$ACTIVE/run.json" status '"abandoned"' || true
  fi
  rm -rf "${RUNS:?}/$old"
  mv "$ACTIVE" "$RUNS/$old"
  echo "parked unfinished run as .idleflow/runs/$old" >&2
}

# Copy a task's report out of its worktree (the worktree is deleted at the end of the run).
# The worktree file is not called report.md: Claude Code's Write tool refuses subagents any
# file named report*.md (also summary, findings, analysis).
report_src() { echo "$(wt_path "$1")/.idleflow-run/result.md"; }
copy_report() {
  local tid="$1" src dst
  src="$(report_src "$tid")"; dst="$ACTIVE/tasks/$tid/report.md"
  [ -f "$src" ] || { echo "no report at $src (the implementer did not write .idleflow-run/result.md)" >&2; return 1; }
  mkdir -p "$ACTIVE/tasks/$tid"
  cp "$src" "$dst"
  idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.t_report" "$(date +%s)"
  native_path "$dst"
}

# The run keeps its own copy of what the conventions say about commands and shared files, so the
# conventions can change on main mid-run without changing this run. The copy is taken at `new` and
# again at the snapshot that ends setup (R1–R6 write and commit conventions after `new`), as long as
# no task exists yet. A command the human chose to run without (`run.sh skip`) stays empty.
conventions_to_run() {
  local key val skipped shared
  skipped="$(idleflow_rt get "$ACTIVE/run.json" skipped 2>/dev/null || true)"
  for key in $REPO_COMMANDS; do
    val="$(repo_command "$key")"
    case "$skipped" in *"\"$key\""*) val="";; esac
    idleflow_rt set "$ACTIVE/run.json" "$key" "$(json_str "$val")"
  done
  shared="$(shared_files | while IFS= read -r f; do json_str "$f"; echo; done | paste -sd, -)"
  idleflow_rt set "$ACTIVE/ownership.json" shared "[${shared}]"
}
run_has_tasks() { [ "$(idleflow_rt get "$ACTIVE/run.json" tasks 2>/dev/null || echo '{}')" != "{}" ]; }

cmd="${1:-}"; shift || true
case "$cmd" in
  new)
    slug="${1:?slug}"
    safe="$(echo "$slug" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-40)"
    id="$(date +%Y%m%d-%H%M%S)-$safe"
    mkdir -p "$RUNS"
    park_active
    mkdir -p "$ACTIVE"/{tasks,debate,review}
    # Both work on an unborn branch (fresh `git init`, no commits yet): base falls back to HEAD, sha to "".
    base="$("${G[@]}" symbolic-ref --short -q HEAD || echo HEAD)"
    base_sha="$("${G[@]}" rev-parse -q --verify HEAD 2>/dev/null || true)"
    cat > "$ACTIVE/run.json" <<JSON
{"id":"$id","plugin_version":$(json_str "$(plugin_version)"),"by":$(json_str "$(git config user.name || echo unknown)"),"slug":"$safe","base":$(json_str "$base"),"base_sha":"$base_sha","started":"$(date -u +%FT%TZ)","status":"planning","size":null,"tasks":{},"retries":0,"gate_trips":0,"review_findings":0}
JSON
    echo "{\"repo\":$(json_str "$(native_path "$REPO")"),\"shared\":[],\"tasks\":{}}" > "$ACTIVE/ownership.json"
    conventions_to_run
    add_ignore "$(ignore_file)" '.idleflow/runs/'
    # worktree marker dir: excluded locally (shared by all worktrees), never committed or merged
    add_ignore "$(exclude_file)" '.idleflow-run/'
    add_ignore "$(exclude_file)" '.idleflow/worktrees/'
    echo "$id"
    ;;
  wt)
    sub="${1:?add|rm|list}"; shift || true
    case "$sub" in
      add)
        id="$(active_id)"
        tid="${1:?task-id}"; check_task_id "$tid"; base="${2:-$(idleflow_rt get "$ACTIVE/run.json" base)}"
        p="$(wt_path "$tid")"; br="idleflow/$id/$tid"
        "${G[@]}" rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "base '$base' has no commits yet; commit first (run.sh snapshot)" >&2; exit 1; }
        # a leftover from a crashed run must not make `add` fail
        "${G[@]}" worktree prune
        if [ -d "$p" ]; then
          "${G[@]}" worktree remove --force "$p" 2>/dev/null || true
          case "$p" in *"$SUFFIX"/*|*/.idleflow/worktrees/*) rm -rf "$p";; esac
        fi
        mkdir -p "$(dirname "$p")"
        "${G[@]}" worktree add -B "$br" "$p" "$base" >/dev/null
        mkdir -p "$p/.idleflow-run" "$ACTIVE/tasks/$tid"
        echo "$tid" > "$p/.idleflow-run/task-id"
        native_path "$REPO" > "$p/.idleflow-run/repo"   # lets the guard hook find the ownership map from inside the worktree
        # the task's own base: groups merged earlier move the branch, so gate/review must diff from here, not from the run start
        idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.base_sha" "\"$("${G[@]}" rev-parse "$base")\""
        idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.worktree" "$(json_str "$(native_path "$p")")"
        idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.port" "$(allocate_port "$tid")"
        mkdir -p "$(task_tmp "$tid")"
        # epoch seconds, so the retro's time log can subtract them without date parsing
        idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.t_start" "$(date +%s)"
        # the commit the first tasks branch from is the base a later gate is compared against
        gb="$(idleflow_rt get "$ACTIVE/run.json" gate_base 2>/dev/null || true)"
        [ -n "$gb" ] && [ "$gb" != null ] || idleflow_rt set "$ACTIVE/run.json" gate_base "\"$("${G[@]}" rev-parse "$base")\""
        run_worktree_setup "$tid" "$p"
        native_path "$p"
        ;;
      rm)
        tid="${1:?task-id}"; check_task_id "$tid"; p="$(wt_path "$tid")"
        # the task's jobs go with its worktree
        for jd in "$ACTIVE/tasks/$tid/jobs"/*/; do [ -d "$jd" ] && stop_job "${jd%/}"; done
        "${G[@]}" worktree remove --force "$p" 2>/dev/null || true
        "${G[@]}" worktree prune
        ;;
      list)
        "${G[@]}" worktree list | grep '\[idleflow/' || true
        ;;
      *) echo "unknown wt subcommand" >&2; exit 1;;
    esac
    ;;
  skip)
    key="${1:?worktree_setup|gate|gate_quick|preview}"; active_id >/dev/null
    case " $REPO_COMMANDS " in *" $key "*) ;; *) echo "skip: $key is not a repo command ($REPO_COMMANDS)" >&2; exit 1;; esac
    list="$(idleflow_rt get "$ACTIVE/run.json" skipped 2>/dev/null || true)"
    case "$list" in ""|null) list="[]";; esac
    case "$list" in *"\"$key\""*) ;; "[]") list="[\"$key\"]";; *) list="${list%]},\"$key\"]";; esac
    idleflow_rt set "$ACTIVE/run.json" skipped "$list"
    idleflow_rt set "$ACTIVE/run.json" "$key" '""'
    ;;
  own)
    tid="${1:?task-id}"; check_task_id "$tid"; globs="${2:?json array}"; active_id >/dev/null
    idleflow_rt own "$ACTIVE/ownership.json" "$tid" "$(native_path "$(wt_path "$tid")")" "$globs"
    ;;
  unowned)
    tid="${1:?task-id}"; check_task_id "$tid"; active_id >/dev/null
    p="$(wt_path "$tid")"; base="$(idleflow_rt get "$ACTIVE/run.json" "tasks.$tid.base_sha")"
    if [ ! -d "$p" ] || [ -z "$base" ] || [ "$base" = null ]; then echo "task $tid has no worktree or base sha (run.sh wt add $tid first)" >&2; exit 1; fi
    # only the task's commits merge, so only they are checked; --no-renames: a rename changes the
    # old path too, and the task must own both
    git -C "$p" diff -z --no-renames --name-only "$base" HEAD | idleflow_rt unowned "$ACTIVE/ownership.json" "$tid"
    ;;
  exec)
    tid="${1:?task-id}"; check_task_id "$tid"; shift; [ "${1:-}" = -- ] && shift
    [ "$#" -gt 0 ] || { echo "usage: run.sh exec <task-id> -- <command...>" >&2; exit 1; }
    active_id >/dev/null
    dir="$(wt_path "$tid")"; [ -d "$dir" ] || { echo "exec: no worktree for $tid (run.sh wt add $tid first)" >&2; exit 1; }
    jobs="$ACTIVE/tasks/$tid/jobs"; mkdir -p "$jobs"
    n=1; while ! mkdir "$jobs/$n" 2>/dev/null; do n=$((n + 1)); done
    jd="$jobs/$n"; printf -v q '%q ' "$@"; printf -v st '%q' "$jd/status"
    # the exit code is written to a temp name and moved, so a reader never sees half of it
    printf -v pf '%q' "$jd/pid"
    in_task "$tid" "$dir" idleflow_rt detach "$dir" "$jd/log" "$jd/pid.runtime" \
      "echo \$\$ > $pf.tmp && mv $pf.tmp $pf; $q; rc=\$?; echo \$rc > $st.tmp && mv $st.tmp $st" || { echo "exec: could not start the command" >&2; exit 1; }
    # the number first, so an agent whose call is cut short still knows which job to wait for
    echo "[idleflow] job $n of $tid started" >&2
    await_job "$tid" "$n"
    ;;
  wait|stop)
    tid="${1:?task-id}"; check_task_id "$tid"; job="${2:?job number}"; active_id >/dev/null
    [[ "$job" =~ ^[0-9]+$ ]] || { echo "$cmd: '$job' is not a job number" >&2; exit 1; }
    if [ "$cmd" = wait ]; then await_job "$tid" "$job"; fi
    [ -f "$(job_dir "$tid" "$job")/pid" ] || { echo "no job $job for task $tid" >&2; exit 1; }
    stop_job "$(job_dir "$tid" "$job")" || exit 1
    echo "job $job of $tid: stopped"
    ;;
  get)
    key="${1:?key}"; active_id >/dev/null
    idleflow_rt get "$ACTIVE/run.json" "$key"
    ;;
  set)
    key="${1:?key}"; val="${2:?json value}"; active_id >/dev/null
    idleflow_rt set "$ACTIVE/run.json" "$key" "$val"
    ;;
  inc)
    key="${1:?key}"; n="${2:-1}"; active_id >/dev/null
    idleflow_rt inc "$ACTIVE/run.json" "$key" "$n"
    ;;
  extract)
    # What every agent working on one task reads of the plan: the sections every task is written
    # against, then the task's own section. Other tasks' sections stay out.
    tid="${1:?task-id}"; check_task_id "$tid"; active_id >/dev/null
    [ -f "$ACTIVE/plan.md" ] || { echo "extract: no plan.md in the active run" >&2; exit 1; }
    # a heading inside a code fence is text, not the start of a section
    out="$(tr -d '\r' < "$ACTIVE/plan.md" | H="### $tid:" awk '
      /^(```|~~~)/ { fence = !fence }
      !fence && /^## / { shared = (index($0, "## Stack & style constraints") == 1 || index($0, "## Interfaces") == 1); task = 0 }
      !fence && /^### / { task = (index($0, ENVIRON["H"]) == 1); if (task) found = 1 }
      shared || task { print }
      END { if (!found) exit 3 }')" || { echo "extract: plan.md has no '### $tid:' section" >&2; exit 1; }
    printf '%s\n' "$out"
    ;;
  report)
    tid="${1:?task-id}"; check_task_id "$tid"; active_id >/dev/null
    copy_report "$tid"
    ;;
  gate)
    tid="${1:?task-id}"; check_task_id "$tid"; active_id >/dev/null
    base="$(idleflow_rt get "$ACTIVE/run.json" "tasks.$tid.base_sha" 2>/dev/null || true)"
    if [ -z "$base" ] || [ "$base" = "null" ]; then base="$(idleflow_rt get "$ACTIVE/run.json" base_sha)"; fi
    [ -n "$base" ] && [ "$base" != "null" ] || { echo "gate $tid: no base sha recorded (was the worktree created with run.sh wt add?)" >&2; exit 1; }
    out="$(bash "$HERE/diff-gate.sh" "$(wt_path "$tid")" "$base" ${2:+"$2"})" || { echo "gate $tid failed: $out" >&2; exit 1; }
    mkdir -p "$ACTIVE/tasks/$tid"
    echo "$out" > "$ACTIVE/tasks/$tid/gate.json"
    # only a retry that rewrote the worktree report refreshes the run copy; a newer run copy is kept
    if [ "$(report_src "$tid")" -nt "$ACTIVE/tasks/$tid/report.md" ]; then copy_report "$tid" >/dev/null; fi
    echo "$out"
    ;;
  merge)
    tid="${1:?task-id}"; check_task_id "$tid"; id="$(active_id)"
    # The task's title says what the merge brings. It is read here from the plan, never passed on a
    # command line: a title with `code` or $name in it would be expanded by the shell that runs the
    # command. One line; the ids go in the body.
    title="$(plan_title "$tid" | tr '\n\r\t' '   ' | sed 's/  */ /g; s/^ //; s/ $//')"; [ -n "$title" ] || title="task $tid"
    br="idleflow/$id/$tid"; p="$(wt_path "$tid")"
    # the "never merge an unapproved task" rule, enforced here and not only in the prompt
    st="$(idleflow_rt get "$ACTIVE/run.json" "tasks.$tid.status" 2>/dev/null || true)"
    [ "$st" = "approved" ] || { echo "refusing to merge $tid: status is '${st:-unset}', not approved" >&2; exit 4; }
    # The subject follows the repo's style and says what merged; only the `idleflow` format, the
    # tool's own, names it. `conventional` repos often check every subject in CI (at most 72
    # characters), so ids live in the body, as trailers every format carries (gen_runs reads them).
    # --no-log: a merge.log setting would append a shortlog after them, and they would stop being
    # the message's trailers.
    case "$(conventions_value commit_format)" in
      conventional) subject="$(idleflow_rt clip 72 "chore: merge $title")";;
      plain) subject="$(idleflow_rt clip 72 "Merge $title")";;
      *) subject="idleflow: merge $tid ($id)";;
    esac
    merge_msg=(-m "$subject" -m "Run: $id
Task: $tid")
    # What merges is the task's commits, the ones the gate measured and the reviewers approved.
    # Anything uncommitted in the worktree (a setup script's output, a cache) stays there.
    if [ -d "$p" ]; then
      left="$(git -C "$p" status -z --no-renames --porcelain -- . ':(exclude).idleflow-run' | { n=0; while IFS= read -r -d '' r && [ "$n" -lt 8 ]; do printf '%s ' "${r:3}"; n=$((n + 1)); done; })"
      left="${left% }"
      [ -z "$left" ] || echo "merge $tid: uncommitted in the worktree, not merged: $left" >&2
    fi
    if "${G[@]}" ${IDENTITY[@]+"${IDENTITY[@]}"} merge --no-ff --no-log -q "${merge_msg[@]}" "$br"; then
      idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.t_merge" "$(date +%s)"
      echo "merged $tid"
    elif [ -f "$("${G[@]}" rev-parse --absolute-git-dir)/MERGE_HEAD" ]; then
      "${G[@]}" merge --abort || true
      echo "CONFLICT merging $tid — resolve by re-running the owning task against the new base, or merge by hand" >&2
      exit 3
    else
      echo "merge of $tid failed before any conflict (dirty checkout? unknown branch $br?)" >&2
      exit 4
    fi
    ;;
  ignore)
    pat="${1:?pattern}"
    f="$(ignore_file)"
    add_ignore "$f" "$pat"
    native_path "$f"
    ;;
  snapshot)
    # The orchestrator creates repo-level docs in the main checkout before any worktree exists.
    # Commit them so worktrees (branched from HEAD) see them. Only these paths are committed,
    # never other staged work; ignored paths (a docs/ kept local) are skipped, never forced.
    [ -f "$("${G[@]}" rev-parse --absolute-git-dir)/MERGE_HEAD" ] && { echo "snapshot: a merge is in progress; finish or abort it first" >&2; exit 1; }
    paths=()
    ensure_union_merge
    for f in $(printf '%s\n' .idleflow CLAUDE.md prd.md "$(progress_rel)" "$(index_rel)" "$(lessons_rel)" README.md .gitignore .gitattributes docs | awk '!seen[$0]++'); do
      [ -e "$REPO/$f" ] || continue
      # the human chose what is ignored (docs_in_git in R2); an ignored path is simply skipped
      if "${G[@]}" check-ignore -q --no-index -- "$f"; then
        echo "snapshot: $f is ignored, not committed" >&2
        continue
      fi
      "${G[@]}" add -A -- "$f"; paths+=("$f")
    done
    if [ "${#paths[@]}" -eq 0 ] || "${G[@]}" diff --cached --quiet -- "${paths[@]}"; then
      echo "snapshot: nothing to commit"
    else
      gcommit -m "docs: project conventions and run inputs" -- "${paths[@]}"
      echo "snapshot: committed $("${G[@]}" rev-parse --short HEAD)"
    fi
    # setup is over: the run now uses the conventions it just committed
    if [ -f "$ACTIVE/run.json" ] && ! run_has_tasks; then conventions_to_run; fi
    ;;
  finish)
    status="${1:-done}"; id="$(active_id)"
    idleflow_rt finish "$ACTIVE/run.json" "$status" "$RUNS/log.jsonl"
    rm -rf "${RUNS:?}/$id"
    mv "$ACTIVE" "$RUNS/$id"
    echo "run $id finished: $status"
    ;;
  loc)
    # Hand-written code lines in the repo: tracked files minus DIFF_EXCLUDE. Docs don't count.
    build_excl
    n="$("${G[@]}" ls-files -z -- . ${EXCL[@]+"${EXCL[@]}"} | xargs -0 -r cat 2>/dev/null | wc -l | tr -d ' ')"
    echo "${n:-0}"
    ;;
  path)
    case "${1:?conventions|lessons|progress|index|sessions|time-log|runs}" in
      conventions) native_path "$CONVENTIONS";;
      lessons) native_path "$(lessons_path)";;
      progress) native_path "$REPO/$(progress_rel)";;
      index) native_path "$REPO/$(index_rel)";;
      sessions) native_path "$REPO/$(sessions_rel)";;
      time-log) native_path "$REPO/$(time_log_rel)";;
      runs) native_path "$RUNS";;
      *) echo "unknown path name: $1" >&2; exit 1;;
    esac
    ;;
  migrate)
    moves=()
    [ -e "$REPO/.claude/conventions.md" ] && moves+=(".claude/conventions.md:.idleflow/conventions.md")
    [ -e "$REPO/.claude/lessons.md" ] && moves+=(".claude/lessons.md:.idleflow/lessons.md")
    if [ "${#moves[@]}" -eq 0 ] && [ ! -d "$REPO/.claude/runs" ]; then echo "migrate: nothing to move"; exit 0; fi
    # a run started by the old version must finish on it: its scripts and agents expect the old paths
    [ -d "$REPO/.claude/runs/active" ] && { echo "migrate: a run is still active in .claude/runs/active; finish it on the idleflow version that started it, then run this again" >&2; exit 1; }
    [ -f "$("${G[@]}" rev-parse --absolute-git-dir)/MERGE_HEAD" ] && { echo "migrate: a merge is in progress; finish or abort it first" >&2; exit 1; }
    [ -d "$REPO/.claude/runs" ] && [ -e "$RUNS" ] && { echo "migrate: both .claude/runs and .idleflow/runs exist; keep one by hand, then run this again" >&2; exit 1; }
    for m in ${moves[@]+"${moves[@]}"}; do
      old="${m%%:*}"; new="${m#*:}"
      [ -e "$REPO/$new" ] && { echo "migrate: both $old and $new exist; keep one by hand, then run this again" >&2; exit 1; }
      [ -z "$("${G[@]}" status --porcelain --untracked-files=no -- "$old")" ] || { echo "migrate: $old has uncommitted changes; commit or discard them first" >&2; exit 1; }
    done
    mkdir -p "$IDLE"
    paths=()
    for m in ${moves[@]+"${moves[@]}"}; do
      old="${m%%:*}"; new="${m#*:}"
      if "${G[@]}" ls-files --error-unmatch -- "$old" >/dev/null 2>&1; then
        "${G[@]}" mv -- "$old" "$new"; paths+=("$old" "$new")
      else
        mv "$REPO/$old" "$REPO/$new"
      fi
      echo "migrate: $old -> $new"
    done
    if [ -d "$REPO/.claude/runs" ]; then
      mv "$REPO/.claude/runs" "$RUNS"
      echo "migrate: .claude/runs/ -> .idleflow/runs/"
    fi
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rewrite_file "$REPO/$f"; "${G[@]}" add -- "$f"; paths+=("$f")
      echo "migrate: rewrote old paths in $f"
    done <<< "$("${G[@]}" grep -lE '\.claude/(conventions\.md|lessons\.md|runs)|\.claude-run/' -- '*.md' .gitignore 2>/dev/null || true)"
    f="$(exclude_file)"
    [ -f "$f" ] && rewrite_file "$f"
    rmdir "$REPO/.claude" 2>/dev/null || true
    if [ "${#paths[@]}" -eq 0 ]; then
      echo "migrate: moved; nothing tracked to commit"
    else
      gcommit -m "chore: move idleflow files to .idleflow/" -- "${paths[@]}"
      echo "migrate: committed $("${G[@]}" rev-parse --short HEAD)"
    fi
    ;;
  session-name)
    # Named by time and author, not by a running number: two people writing a note on the same
    # day would otherwise both pick the next number.
    dir="$(sessions_rel)"
    if [ "$(conventions_value session_names)" = per-person ]; then
      # each person numbers their own folder, so two writers never pick the same file
      dir="$dir/$(person_id)"; who_n="$({ ls "$REPO/$dir" 2>/dev/null || true; } | sed -n 's/^s_\([0-9][0-9][0-9][0-9]\)\.md$/\1/p' | sort -n | tail -1)"
      printf '%s/s_%04d.md\n' "$dir" "$((10#${who_n:-0} + 1))"
      exit 0
    fi
    if [ "$(conventions_value session_names)" = numbered ]; then
      # a repo that numbers its notes (s_0001.md, ...) keeps doing so; with several writers it can collide
      last="$({ ls "$REPO/$dir" 2>/dev/null || true; } | sed -n 's/^s_\([0-9][0-9][0-9][0-9]\)\.md$/\1/p' | sort -n | tail -1)"
      printf '%s/s_%04d.md\n' "$dir" "$((10#${last:-0} + 1))"
      exit 0
    fi
    who="$(author_slug)"; base="$dir/s_$(date +%Y%m%d-%H%M)-${who:-anon}"; f="$base.md"; n=2
    while [ -e "$REPO/$f" ]; do f="$base-$n.md"; n=$((n+1)); done
    echo "$f"
    ;;
  behind)
    "${G[@]}" rev-parse -q --verify '@{u}' >/dev/null 2>&1 || exit 0
    GIT_TERMINAL_PROMPT=0 "${G[@]}" fetch -q 2>/dev/null || exit 0
    n="$("${G[@]}" rev-list --count 'HEAD..@{u}')"
    [ "$n" -gt 0 ] && echo "$n"
    exit 0
    ;;
  team-install)
    f="$REPO/.claude/settings.json"
    mkdir -p "$REPO/.claude"
    [ -s "$f" ] || echo '{}' > "$f"
    idleflow_rt set "$f" extraKnownMarketplaces.idlesync '{"source":{"source":"github","repo":"Idle-Sync/idleflow"}}' 2>/dev/null \
      || { echo "team-install: $f is not valid JSON; fix it first" >&2; exit 1; }
    idleflow_rt set "$f" enabledPlugins.idleflow@idlesync true
    native_path "$f"
    # Claude reads CLAUDE.md with or without the plugin, so this note reaches a teammate whose
    # session has not loaded idleflow (folder not trusted yet, a cloud session).
    if ! grep -q '<!-- idleflow install start -->' "$REPO/CLAUDE.md" 2>/dev/null; then
      [ ! -s "$REPO/CLAUDE.md" ] || [ -z "$(tail -c1 "$REPO/CLAUDE.md")" ] || echo >> "$REPO/CLAUDE.md"
      [ ! -s "$REPO/CLAUDE.md" ] || echo >> "$REPO/CLAUDE.md"
      cat "$HERE/../templates/install-note.md" >> "$REPO/CLAUDE.md"
    fi
    native_path "$REPO/CLAUDE.md"
    ;;
  docs)
    # Regenerates every generated block in the repo's Markdown; --check only reports stale ones (exit 1).
    mode="${1:-write}"; cd "$REPO"
    stale=(); changed=()
    files="$(generated_doc_files)"
    tmp_doc="$(mktemp)"; tmp_block="$(mktemp)"
    while IFS= read -r f; do
      [ -n "$f" ] && [ -f "$f" ] || continue
      : > "$tmp_doc"; name=""
      while IFS= read -r line || [ -n "$line" ]; do
        if [ -z "$name" ] && [[ "$line" =~ $DOC_START_RE ]]; then
          name="${BASH_REMATCH[1]}"; : > "$tmp_block"; printf '%s\n' "$line" >> "$tmp_doc"; continue
        fi
        if [ -n "$name" ]; then
          if [ "$line" = "$DOC_END" ]; then
            if declare -F "gen_${name//-/_}" >/dev/null; then "gen_${name//-/_}" "$tmp_block" >> "$tmp_doc"
            else echo "docs: $f: no generator named '$name'; block left as it is" >&2; cat "$tmp_block" >> "$tmp_doc"; fi
            printf '%s\n' "$line" >> "$tmp_doc"; name=""
          else printf '%s\n' "$line" >> "$tmp_block"; fi
          continue
        fi
        printf '%s\n' "$line" >> "$tmp_doc"
      done < "$f"
      [ -z "$name" ] || { echo "docs: $f: block '$name' has no end marker; file left as it is" >&2; continue; }
      cmp -s "$tmp_doc" "$f" && continue
      if [ "$mode" = --check ]; then stale+=("$f"); else cat "$tmp_doc" > "$f"; changed+=("$f"); fi
    done <<< "$files"
    rm -f "$tmp_doc" "$tmp_block"
    if [ "$mode" = --check ]; then
      [ "${#stale[@]}" -eq 0 ] || { echo "docs: out of date: ${stale[*]} (run.sh docs regenerates them)"; exit 1; }
      echo "docs: generated blocks are up to date"
    elif [ "${#changed[@]}" -gt 0 ]; then echo "docs: regenerated ${changed[*]}"
    else echo "docs: generated blocks are up to date"; fi
    ;;
  detect)
    # Evidence for the Repo fit and Records settings, one `suggest <key>: <value> — <evidence>` line
    # for each key still unset whose evidence points away from the default. Read-only.
    unset_key() { case "$(conventions_value "$1")" in ""|unset) return 0;; *) return 1;; esac; }
    # a suggestion the human declined stays quiet for every caller (setup, the doctor, a run's end)
    say() { grep -qF -- "- declined: $1 -> $2 " "$IDLE/suggestions.md" 2>/dev/null || echo "suggest $1: $2 — $3"; }
    if unset_key commit_format; then
      subjects="$("${G[@]}" log --no-merges -50 --format=%s 2>/dev/null || true)"
      total="$(printf '%s' "$subjects" | grep -c . || true)"
      cc="$(printf '%s\n' "$subjects" | grep -Ec '^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([A-Za-z0-9_./-]+\))?!?: ' || true)"
      if [ "${total:-0}" -ge 10 ] && [ $((cc * 100 / total)) -ge 80 ]; then say commit_format conventional "$cc of the last $total commit subjects are Conventional Commits"; fi
      # plain sentences: no type prefix and no `<id>: ` prefix, starting with a capital letter
      capital="$(printf '%s\n' "$subjects" | grep -Ev '^[A-Za-z0-9_()./!-]+: ' | grep -c '^[A-Z]' || true)"
      if [ "${total:-0}" -ge 10 ] && [ $((capital * 100 / total)) -ge 80 ]; then say commit_format plain "$capital of the last $total commit subjects are plain sentences with no prefix"; fi
    fi
    if unset_key lessons_in && [ -f "$REPO/lessons.md" ] && [ ! -f "$IDLE/lessons.md" ]; then say lessons_in lessons.md "the repo already keeps lessons.md"; fi
    if unset_key progress_file && [ ! -f "$REPO/progress.md" ] && [ -f "$REPO/docs/progress.md" ]; then say progress_file docs/progress.md "the repo keeps docs/progress.md"; fi
    if unset_key session_names; then
      dir="$REPO/$(sessions_rel)"
      [ -d "$dir" ] || dir="$REPO/docs/sessions"
      people="$({ "${G[@]}" log --format='%ae' 2>/dev/null || true; } | sort -u | grep -c . || true)"
      if ls "$dir"/*/ 2>/dev/null | grep -qE '^s_[0-9]{4}\.md$'; then say session_names per-person "notes in ${dir#"$REPO"/} are already in one folder per person"
      elif ls "$dir" 2>/dev/null | grep -qE '^s_[0-9]{4}\.md$'; then
        if [ "${people:-1}" -gt 1 ]; then say session_names per-person "notes are numbered s_NNNN.md and $people people commit here; a folder per person keeps the numbering without collisions"
        else say session_names numbered "$(ls "$dir" | grep -cE '^s_[0-9]{4}\.md$') notes in ${dir#"$REPO"/} are numbered s_NNNN.md"; fi
      fi
    fi
    if unset_key index_rewrite && [ -f "$REPO/$(index_rel)" ] && ! grep -qE "Rewritten by the idleflow retro|idleflow:generated" "$REPO/$(index_rel)"; then
      say index_rewrite no "$(index_rel) was not written by idleflow, so the repo keeps it its own way"
    fi
    if unset_key shared_files; then
      shared=()
      grep -qiE '^## \[?unreleased' "$REPO/CHANGELOG.md" 2>/dev/null && shared+=(CHANGELOG.md)
      [ "$(conventions_value index_rewrite)" = no ] && [ -f "$REPO/$(index_rel)" ] && shared+=("$(index_rel)")
      [ "${#shared[@]}" -gt 0 ] && say shared_files "${shared[*]}" "every change adds a line here (an Unreleased changelog section, an index the repo keeps itself)"
    fi
    if [ -f "$REPO/$(index_rel)" ] && ! grep -q "idleflow:generated" "$REPO/$(index_rel)"; then
      say generated_docs "$(index_rel)" "it has no generated blocks, so its file list, commands and dependencies are kept by hand; run.sh docs can keep them from the repo"
    fi
    if unset_key worktrees_in && grep -qiE '(outside|beyond) (of )?(this|the) (folder|directory|repo|repository|project)' "$REPO/CLAUDE.md" 2>/dev/null; then
      say worktrees_in inside "CLAUDE.md forbids working outside this folder"
    fi
    # the slowest full gate the last few runs measured
    slowest="$({ tail -10 "$RUNS/log.jsonl" 2>/dev/null || true; } | { grep -o '"gate_seconds_max":[0-9]*' || true; } | cut -d: -f2 | sort -n | tail -1)"
    if [ -n "$slowest" ] && [ "$slowest" -gt "${SLOW_GATE_SECONDS:-120}" ]; then
      unset_key gate_runs && say gate_runs once "the gate took ${slowest}s in a recent run (over ${SLOW_GATE_SECONDS:-120}s); once per run instead of once per task, with gate_quick per task"
      unset_key gate_quick && say gate_quick "<a fast subset: the tests nearest the change, a lint, a type check>" "a slow gate needs a quick check for each task"
      tests_re='pytest|jest|vitest|mocha|go test|cargo test|npm (run )?test|yarn test|pnpm test|mvn .*test|gradle.* test|tox|rspec|phpunit|make (test|check)|gate'
      for h in .husky/pre-commit .husky/pre-push .git/hooks/pre-commit .git/hooks/pre-push .pre-commit-config.yaml lefthook.yml lefthook.yaml; do
        [ -f "$REPO/$h" ] && grep -qE "$tests_re" "$REPO/$h" && say hooks "move the tests out of $h" "it runs tests on every commit or push, and each idleflow task commits several times while the gate takes ${slowest}s"
      done
    fi
    # A task worktree starts with no Python environment. Borrowing the main checkout's runs the main
    # checkout's code (its editable install) in any child process that does not inherit PYTHONPATH,
    # so each worktree builds its own. `none` is the repo's decision to go without, so only an
    # undecided line gets the proposal; a declined one is remembered in suggestions.md.
    # shellcheck disable=SC2016 # a command for the repo's shell to run later, not to expand here
    VENV_CMD='py="$(command -v python3 || command -v python)" && "$py" -m venv .venv && vpy=.venv/bin/python && { [ -x "$vpy" ] || vpy=.venv/Scripts/python.exe; } && "$vpy" -m pip install -q'
    if unset_key worktree_setup; then
      env_cmd=""
      if [ -d "$REPO/.venv" ]; then
        if [ -f "$REPO/uv.lock" ]; then env_cmd="uv sync --frozen"
        elif [ -f "$REPO/poetry.lock" ]; then env_cmd="POETRY_VIRTUALENVS_IN_PROJECT=true poetry install"
        # The command is committed and runs on every teammate's clone, so it cannot assume one OS:
        # the interpreter is python3 or python, and a venv keeps it in bin/ or, on Windows, Scripts/.
        elif [ -f "$REPO/pyproject.toml" ] || [ -f "$REPO/setup.py" ]; then env_cmd="$VENV_CMD -e ."
        elif [ -f "$REPO/requirements.txt" ]; then env_cmd="$VENV_CMD -r requirements.txt"
        fi
      fi
      [ -n "$env_cmd" ] && say worktree_setup "$env_cmd" "the main checkout has .venv/ and a task worktree starts without one; borrowing the main one runs the main checkout's code in subprocesses"
    fi
    if unset_key preview; then
      for t in dev start preview; do
        if grep -qE "\"$t\"[[:space:]]*:" "$REPO/package.json" 2>/dev/null; then say preview "npm run $t" "package.json has a $t script; the design reviewer can serve the app to take screenshots (setup asks for its address)"; break; fi
      done
    fi
    if unset_key gate; then
      cands=()
      for f in tools/gate.py scripts/gate.py tools/gate.sh scripts/gate.sh scripts/check.sh bin/check; do
        [ -f "$REPO/$f" ] || continue
        case "$f" in *.py) cands+=("python3 $f");; *.sh) cands+=("bash $f");; *) cands+=("./$f");; esac
      done
      for t in check gate ci; do grep -qE "^$t:" "$REPO/Makefile" 2>/dev/null && cands+=("make $t"); grep -qE "^$t:" "$REPO/justfile" 2>/dev/null && cands+=("just $t"); done
      for t in check ci test; do
        line="$(grep -E "\"$t\"[[:space:]]*:" "$REPO/package.json" 2>/dev/null | head -1 || true)"
        # npm init's placeholder test script fails on purpose and checks nothing
        [ -n "$line" ] && ! echo "$line" | grep -q "no test specified" && cands+=("npm run $t")
      done
      [ "${#cands[@]}" -gt 0 ] && say gate "${cands[0]}" "candidates found: $(printf '%s, ' "${cands[@]}" | sed 's/, $//')"
    fi
    exit 0
    ;;
  repo-gate)
    # The repo's own check, the definition of done: on the base the tasks branch from (so earlier
    # breakage is not blamed on the run), in a task's worktree (--quick: gate_quick), or after merge.
    target="${1:?base|main|<task-id>}"; key=gate; [ "${2:-}" = --quick ] && key=gate_quick
    case "$target" in base|main) ;; *) check_task_id "$target";; esac
    active_id >/dev/null
    cmd="$(idleflow_rt get "$ACTIVE/run.json" "$key" 2>/dev/null || true)"
    case "$cmd" in ""|null) echo "repo $key: none"; exit 0;; esac
    command_approved "$key" "$cmd" || { echo "$key is not approved on this clone; nothing ran. The command is: $cmd" >&2; exit 7; }
    tmp_base=""
    case "$target" in
      main) dir="$REPO"; log="$ACTIVE/repo-$key-main.log";;
      base)
        log="$ACTIVE/repo-$key-base.log"
        gb="$(idleflow_rt get "$ACTIVE/run.json" gate_base 2>/dev/null || true)"; head="$("${G[@]}" rev-parse HEAD)"
        if [ -z "$gb" ] || [ "$gb" = null ]; then gb="$head"; idleflow_rt set "$ACTIVE/run.json" gate_base "\"$gb\""; fi
        if [ "$gb" = "$head" ]; then
          if [ -n "$("${G[@]}" status --porcelain --untracked-files=no)" ]; then
            echo "repo-gate base: the main checkout has uncommitted changes, so it is not the base; commit or stash them first" >&2; exit 1
          fi
          dir="$REPO"
        else
          # the main checkout has moved on (with gate_runs: once the base is checked only after a failing merge)
          tmp_base="$(wt_path _gate-base)"; mkdir -p "$ACTIVE/tasks/_gate-base" "$(dirname "$tmp_base")"
          "${G[@]}" worktree remove --force "$tmp_base" 2>/dev/null || true
          "${G[@]}" worktree add -q --detach "$tmp_base" "$gb" >/dev/null 2>&1
          run_worktree_setup _gate-base "$tmp_base"
          dir="$tmp_base"
        fi;;
      *) dir="$(wt_path "$target")"; log="$ACTIVE/tasks/$target/repo-$key.log"; mkdir -p "$ACTIVE/tasks/$target"
         [ -d "$dir" ] || { echo "repo-gate: no worktree for $target" >&2; exit 1; };;
    esac
    echo "repo $key ($target): $cmd" >&2
    started="$(date +%s)"
    set +e
    case "$target" in
      base|main) (cd "$dir" && without_agent_markers && MAIN="$REPO" bash -c "$cmd") > "$log" 2>&1;;
      *) in_task "$target" "$dir" bash -c "$cmd" > "$log" 2>&1;;
    esac
    rc=$?
    set -e
    secs=$(( $(date +%s) - started ))
    [ -z "$tmp_base" ] || "${G[@]}" worktree remove --force "$tmp_base" 2>/dev/null || true
    if [ "$key" = gate ]; then
      most="$(idleflow_rt get "$ACTIVE/run.json" gate_seconds_max 2>/dev/null || true)"
      if [ -z "$most" ] || [ "$most" = null ] || [ "$secs" -gt "$most" ]; then idleflow_rt set "$ACTIVE/run.json" gate_seconds_max "$secs"; fi
    fi
    echo "repo $key $target: exit $rc in ${secs}s (full output: $(native_path "$log"))"
    tail -15 "$log"
    if [ "$key" = gate ] && [ "$secs" -gt "${SLOW_GATE_SECONDS:-120}" ] && [ "$(conventions_value gate_runs)" != once ]; then
      echo "slow: the gate took ${secs}s (over SLOW_GATE_SECONDS=${SLOW_GATE_SECONDS:-120}); running it for every task multiplies that. /idleflow:doctor suggests gate_runs: once with a quick check per task." >&2
    fi
    [ "$rc" -eq 0 ] || exit 1
    ;;
  preview)
    # Serves the app from a task worktree for the design reviewer's screenshots, under the same
    # approval rule as the gate; the address must be on this machine.
    tid="${1:?task-id}"; check_task_id "$tid"; act="${2:?start|stop}"; active_id >/dev/null
    pidf="$ACTIVE/tasks/$tid/preview.pid"
    if [ "$act" = stop ]; then
      # the server runs in its own session, so its whole process group goes (dev servers start children)
      if [ -f "$pidf" ]; then pid="$(cat "$pidf")"; kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true; fi
      rm -f "$pidf"; echo "preview $tid: stopped"; exit 0
    fi
    cmd="$(idleflow_rt get "$ACTIVE/run.json" preview 2>/dev/null || true)"
    case "$cmd" in ""|null) echo "preview: none"; exit 0;; esac
    command_approved preview "$cmd" || { echo "preview is not approved on this clone; nothing ran. The command is: $cmd" >&2; exit 7; }
    url="$(conventions_value preview_url)"; port="$(task_port "$tid")"
    url="${url//\$\{IDLEFLOW_PORT\}/$port}"
    [[ "$url" =~ ^https?://(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?(/[^[:space:]]*)?$ ]] \
      || { echo "preview_url must be a localhost address (got '$url')" >&2; exit 1; }
    dir="$(wt_path "$tid")"; [ -d "$dir" ] || { echo "preview: no worktree for $tid" >&2; exit 1; }
    mkdir -p "$ACTIVE/tasks/$tid"
    echo "preview ($tid): $cmd" >&2
    mkdir -p "$(task_tmp "$tid")"
    ( without_agent_markers
      MAIN="$REPO" IDLEFLOW_TASK="$tid" IDLEFLOW_PORT="$port" IDLEFLOW_TMP="$(task_tmp "$tid")" TMPDIR="$(task_tmp "$tid")" \
        idleflow_rt detach "$dir" "$ACTIVE/tasks/$tid/preview.log" "$pidf" "$cmd" )
    echo "preview $tid: serving at $url (log: $(native_path "$ACTIVE/tasks/$tid/preview.log"); stop with: run.sh preview $tid stop)"
    ;;
  commands)
    # every repo command with its committed text and whether this person approved it
    for key in $REPO_COMMANDS; do
      cmd="$(repo_command "$key")"
      [ -n "$cmd" ] || continue
      if command_approved "$key" "$cmd"; then echo "approved $key: $cmd"; else echo "unapproved $key: $cmd"; fi
    done
    ;;
  approve)
    key="${1:?worktree_setup|gate|gate_quick|preview}"
    case " $REPO_COMMANDS " in *" $key "*) ;; *) echo "approve: unknown command key '$key'" >&2; exit 1;; esac
    cmd="$(repo_command "$key")"
    [ -n "$cmd" ] || { echo "approve: no committed $key in .idleflow/conventions.md" >&2; exit 1; }
    "${G[@]}" config --local "$(approval_key "$key")" "$(command_hash "$cmd")"
    echo "approved $key: $cmd"
    ;;
  agent)
    a="${1:-}"; known_agent "$a"
    if [ -f "$(replacement_path "$a")" ]; then
      echo "agent: idleflow-$a"
      echo "contract: $(native_path "$HERE/../agents/$a.md")"
    else
      echo "agent: idleflow:$a"
      echo "contract: built in"
    fi
    m="MODEL_$(agent_key "$a")"; echo "model: ${!m:-default}"
    if [ -f "$IDLE/agents/$a.md" ]; then echo "extra: $(native_path "$IDLE/agents/$a.md")"; else echo "extra: none"; fi
    ;;
  custom)
    sub="${1:?list|set|unset|replace|merge|restore}"; shift || true
    case "$sub" in
      list)
        if [ -f "$PROJECT_CONF" ]; then
          while IFS= read -r line || [ -n "$line" ]; do
            line="${line%$'\r'}"
            if [ "${line%%=*}" != "$line" ] && idleflow_conf_valid "${line%%=*}" "${line#*=}"; then echo "$line"; fi
          done < "$PROJECT_CONF"
        fi
        for f in "$IDLE"/agents/*.md; do
          [ -f "$f" ] || continue
          case "$f" in *.base.md) continue;; esac
          echo "instructions: $(basename "$f" .md) (.idleflow/agents/$(basename "$f"))"
        done
        for f in "$REPO"/.claude/agents/idleflow-*.md; do
          if [ -f "$f" ]; then echo "replaced: $(basename "$f" .md | sed 's/^idleflow-//') (.claude/agents/$(basename "$f"))"; fi
        done
        ;;
      set)
        key="${1:?KEY}"; val="${2:?value}"
        idleflow_conf_valid "$key" "$val" || { echo "custom set: '$key=$val' is not a setting this project may use (see scripts/conf.sh)" >&2; exit 1; }
        case "$key" in
          MODEL_*) known_agent "$(echo "${key#MODEL_}" | tr 'A-Z_' 'a-z-')";;
          REPLACED_*) echo "custom set: REPLACED_ keys are written by custom replace and custom merge" >&2; exit 1;;
        esac
        set_project_conf "$key" "$val"
        echo "$key=$val"
        ;;
      report)
        case "${1:-}" in
          "") report_preference;;
          ask|always|never) "${G[@]}" config --local idleflow.reportCustomizations "$1"; echo "$1";;
          *) echo "custom report: ask, always or never" >&2; exit 1;;
        esac
        ;;
      unset)
        key="${1:?KEY}"
        [ -f "$PROJECT_CONF" ] && set_project_conf "$key"
        echo "$key: plugin default"
        ;;
      replace)
        a="${1:-}"; known_agent "$a"; dst="$(replacement_path "$a")"
        [ -e "$dst" ] && { echo "custom replace: $dst already exists" >&2; exit 1; }
        mkdir -p "$(dirname "$dst")" "$IDLE/agents"
        renamed_agent "$a" > "$dst"
        renamed_agent "$a" > "$IDLE/agents/$a.base.md"
        set_project_conf "REPLACED_$(agent_key "$a")" "$(plugin_version)"
        native_path "$dst"
        ;;
      merge)
        a="${1:-}"; known_agent "$a"; dst="$(replacement_path "$a")"; base="$IDLE/agents/$a.base.md"
        [ -f "$dst" ] && [ -f "$base" ] || { echo "custom merge: $a is not replaced here (no $dst or no $base)" >&2; exit 1; }
        current="$IDLE/agents/$a.current.tmp"
        renamed_agent "$a" > "$current"
        if cmp -s "$current" "$base"; then rm -f "$current"; echo "custom merge: the built-in $a has not changed since it was copied"; exit 0; fi
        was="$(sed -n "s/^REPLACED_$(agent_key "$a")=//p" "$PROJECT_CONF" 2>/dev/null)"
        set +e
        git merge-file -L "this project's $a" -L "idleflow ${was:-before}" -L "idleflow $(plugin_version)" "$dst" "$base" "$current"
        conflicts=$?
        set -e
        [ "$conflicts" -ge 0 ] || { rm -f "$current"; echo "custom merge: git merge-file failed" >&2; exit 1; }
        mv "$current" "$base"
        set_project_conf "REPLACED_$(agent_key "$a")" "$(plugin_version)"
        if [ "$conflicts" -gt 0 ]; then echo "custom merge: $conflicts conflict(s) marked in $(native_path "$dst"); resolve them before the next run" >&2; exit 5; fi
        echo "custom merge: $a now includes idleflow $(plugin_version)"
        ;;
      restore)
        a="${1:-}"; known_agent "$a"
        rm -f "$(replacement_path "$a")" "$IDLE/agents/$a.base.md" "$IDLE/agents/$a.md"
        if [ -f "$PROJECT_CONF" ]; then set_project_conf "REPLACED_$(agent_key "$a")"; set_project_conf "MODEL_$(agent_key "$a")"; fi
        echo "custom restore: $a is the built-in agent again"
        ;;
      *) echo "unknown custom subcommand" >&2; exit 1;;
    esac
    ;;
  update-check)
    latest="$(newest_release)"
    if [ -n "$latest" ] && version_newer "$(plugin_version)" "$latest"; then
      echo "idleflow $latest is available (installed $(plugin_version)). Update between sessions: $UPDATE_CMD, then restart Claude Code."
    fi
    ;;
  doctor)
    rt="$(idleflow_rt_name)"
    if [ "$rt" = none ]; then check_line fail runtime "no Python >= 3.8 or Node >= 18" "install one, or set IDLEFLOW_RUNTIME"; else check_line ok runtime "$rt"; fi

    installed="$(plugin_version)"; latest="$(newest_release)"
    if [ -n "${IDLEFLOW_NO_UPDATE_CHECK:-}" ]; then check_line ok update "check skipped (IDLEFLOW_NO_UPDATE_CHECK), installed $installed"
    elif [ -z "$latest" ]; then check_line warn update "could not read releases from github.com/Idle-Sync/idleflow (installed $installed)"
    elif version_newer "$installed" "$latest"; then check_line warn update "idleflow $latest is available, installed $installed" "$UPDATE_CMD, then restart Claude Code"
    else check_line ok update "idleflow $installed is the newest release"; fi

    old=()
    for f in .claude/conventions.md .claude/lessons.md .claude/runs; do [ -e "$REPO/$f" ] && old+=("$f"); done
    if [ "${#old[@]}" -gt 0 ]; then check_line fail layout "files from the old layout: ${old[*]}" "run.sh migrate"; else check_line ok layout "idleflow files are in .idleflow/"; fi

    if [ ! -f "$CONVENTIONS" ]; then
      check_line fail conventions ".idleflow/conventions.md is missing" "/idleflow:setup"
    else
      missing=()
      for k in mode ignore_in docs; do case "$(conventions_value "$k")" in ""|unset) missing+=("$k");; esac; done
      if [ "$(conventions_value docs)" = yes ]; then
        case "$(conventions_value docs_in_git)" in ""|unset) missing+=(docs_in_git);; esac
        [ "$(conventions_value docs_in_git)" = yes ] && case "$(conventions_value lessons_in)" in ""|unset) missing+=(lessons_in);; esac
      fi
      if [ "${#missing[@]}" -gt 0 ]; then check_line warn conventions "not answered yet: ${missing[*]}" "/idleflow:setup"; else check_line ok conventions "every setting answered"; fi
    fi

    lessons="$(lessons_path)"; lessons_rel="${lessons#"$REPO"/}"
    if [ ! -f "$lessons" ]; then check_line warn lessons "$lessons_rel is missing" "/idleflow:setup"
    elif [ "$lessons_rel" = docs/lessons.md ] && [ -f "$IDLE/lessons.md" ]; then check_line warn lessons "two lessons files: docs/lessons.md (in use) and .idleflow/lessons.md" "merge .idleflow/lessons.md into docs/lessons.md, then git rm .idleflow/lessons.md"
    else check_line ok lessons "$lessons_rel"; fi

    for f in .idleflow/conventions.md "$lessons_rel"; do
      [ -f "$REPO/$f" ] || continue
      if "${G[@]}" check-ignore -q --no-index -- "$f"; then check_line warn shared "$f is ignored, so the team never sees it" "remove the rule that ignores it"
      elif ! "${G[@]}" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then check_line warn shared "$f is not committed yet" "run.sh snapshot"
      else check_line ok shared "$f is committed"; fi
    done

    if [ -d "$RUNS" ] && ! "${G[@]}" check-ignore -q --no-index -- .idleflow/runs/x; then check_line warn ignore ".idleflow/runs/ is not ignored" "run.sh ignore .idleflow/runs/"; else check_line ok ignore ".idleflow/runs/ stays out of git"; fi

    worktrees="$("${G[@]}" worktree list | grep '\[idleflow/' || true)"
    if [ -f "$ACTIVE/run.json" ]; then
      check_line ok run "run $(idleflow_rt get "$ACTIVE/run.json" id) is active (status $(idleflow_rt get "$ACTIVE/run.json" status))"
    elif [ -n "$worktrees" ]; then
      check_line warn worktrees "leftover worktrees with no active run: $(echo "$worktrees" | sed 's#.*\[idleflow/[^/]*/\(.*\)\]#\1#' | tr '\n' ' ')" "run.sh wt rm <task-id> for each"
    else check_line ok worktrees "none left over"; fi

    if [ -f "$PROJECT_CONF" ]; then
      bad="$(idleflow_load_conf "$REPO" 2>&1 >/dev/null | sed 's/^\[idleflow\] ignored in .idleflow\/idleflow.conf: //' | tr '\n' ';' || true)"
      [ -z "$bad" ] || check_line warn customizations "lines skipped in .idleflow/idleflow.conf: ${bad%;}" "/idleflow:customize"
    fi
    custom="$(bash "$0" custom list 2>/dev/null | paste -sd ';' - | sed 's/;/; /g')"
    check_line ok customizations "${custom:-none}"
    for f in "$REPO"/.claude/agents/idleflow-*.md; do
      [ -f "$f" ] || continue
      a="$(basename "$f" .md | sed 's/^idleflow-//')"
      if [ ! -f "$HERE/../agents/$a.md" ]; then check_line warn agents "$a is replaced but idleflow has no agent by that name any more" "run.sh custom restore $a, or delete $f"
      elif [ ! -f "$IDLE/agents/$a.base.md" ]; then check_line warn agents "$a is replaced but its base copy is missing, so updates cannot be merged" "run.sh custom restore $a, then replace it again"
      elif ! cmp -s <(renamed_agent "$a") "$IDLE/agents/$a.base.md"; then check_line warn agents "the built-in $a changed since this project replaced it" "run.sh custom merge $a"
      else check_line ok agents "replaced $a is current with idleflow $(plugin_version)"; fi
    done
    for f in "$IDLE"/agents/*.md; do
      [ -f "$f" ] || continue
      case "$f" in *.base.md) continue;; esac
      [ -f "$HERE/../agents/$(basename "$f")" ] || check_line warn agents "instructions for unknown agent $(basename "$f" .md)" "rename or delete $f"
    done

    behind="$(bash "$0" behind 2>/dev/null || true)"
    if [ -n "$behind" ]; then check_line warn sync "this branch is $behind commit(s) behind its upstream: teammates' lessons and settings are missing" "git pull --ff-only"; fi
    people="$({ "${G[@]}" log --format='%ae' 2>/dev/null || true; } | sort -u | grep -c . || true)"
    if grep -q '"idleflow@idlesync"' "$REPO/.claude/settings.json" 2>/dev/null; then check_line ok team ".claude/settings.json recommends idleflow to everyone who opens the repo"
    elif [ "${people:-0}" -gt 1 ]; then check_line warn team "$people people commit here, but .claude/settings.json does not recommend idleflow, so teammates work without it" "run.sh team-install"
    else check_line ok team "one contributor so far (run.sh team-install when others join)"; fi
    union_missing=""
    # only files that exist yet: a log no run has written cannot conflict, and snapshot adds its rule anyway
    attrs="$(attributes_file)"
    while IFS= read -r f; do [ -e "$REPO/$f" ] || continue; grep -qxF "$f merge=union" "$attrs" 2>/dev/null || union_missing="$union_missing $f"; done < <(union_merge_targets)
    if [ -n "$union_missing" ]; then check_line warn merges "no union merge for:$union_missing, so concurrent entries conflict" "run.sh snapshot"; else check_line ok merges "lessons, progress and suggestions merge without conflicts"; fi

    while IFS= read -r line; do
      case "$line" in
        approved\ *) check_line ok commands "${line#approved }";;
        unapproved\ *) key="${line#unapproved }"; key="${key%%:*}"
          check_line warn commands "not approved by you yet, so it never runs: ${line#unapproved }" "read the command, then run.sh approve $key";;
      esac
    done <<< "$(bash "$0" commands 2>/dev/null || true)"

    gen="$(bash "$0" docs --check 2>/dev/null || true)"
    case "$gen" in "docs: out of date"*) check_line warn generated "${gen#docs: }" "run.sh docs";; "docs: generated blocks are up to date") check_line ok generated "every generated block matches the repo";; esac
    undescribed="$({ "${G[@]}" grep -h -F -e '— (describe)' -- '*.md' 2>/dev/null || true; } | grep -c . || true)"
    [ "${undescribed:-0}" -gt 0 ] && check_line warn generated "$undescribed generated entr$([ "$undescribed" = 1 ] && echo y || echo ies) still say (describe)" "replace each with one line on what it is for"

    # Paths the docs name in backticks that no longer exist. Only tokens whose first folder exists in
    # the repo are checked, so a branch (origin/main) or a GitHub name (owner/repo) never counts.
    stale=()
    for doc in CLAUDE.md "$(index_rel)" "$(progress_rel)"; do
      [ -f "$REPO/$doc" ] || continue
      while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        tok="${tok#./}"
        [ -e "$REPO/${tok%%/*}" ] || continue
        [ -e "$REPO/$tok" ] || stale+=("$doc: $tok")
      done < <(awk '/^[[:space:]]*```/{fenced=!fenced; next} !fenced' "$REPO/$doc" | grep -o '`[^`]*`' | tr -d '`' \
        | grep -E '^(\./)?[A-Za-z0-9_][A-Za-z0-9_.-]*/[A-Za-z0-9_./-]*$' | grep -v '\.\.' | sort -u)
    done
    if [ "${#stale[@]}" -gt 0 ]; then
      check_line warn paths "${#stale[@]} path(s) the docs name do not exist: $(printf '%s\n' "${stale[@]}" | head -5 | paste -sd ';' - | sed 's/;/; /g')" "fix the doc, or restore the file it names"
    else
      check_line ok paths "every path CLAUDE.md, the index and the progress file name exists"
    fi

    # settings that would fit this repo better, from evidence; declined ones stay quiet
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      kv="${line#suggest }"; key="${kv%%:*}"; rest="${kv#*: }"; val="${rest%% — *}"
      if [ "$key" = hooks ]; then
        check_line suggest "fit hooks" "$val (${rest#* — })" "move that step to one run, before the push or in CI; idleflow never edits hooks"
      else
        check_line suggest "fit $key" "$val (${rest#* — })" "/idleflow:setup, which asks before changing anything"
      fi
    done <<< "$(bash "$0" detect 2>/dev/null || true)"

    # the retro's suggestions, newest per key, minus those declined or already applied
    if [ -f "$RUNS/config-proposals.md" ]; then
      while IFS=$'\t' read -r key val line; do
        [[ "$key" =~ ^[A-Z][A-Z_]*$ ]] || continue
        grep -qF -- "- declined: $key -> $val " "$IDLE/suggestions.md" 2>/dev/null && continue
        [ "${!key:-}" = "$val" ] && continue
        check_line suggest "$key" "${line#- }" "/idleflow:customize $key $val"
      done < <(awk 'match($0, /^- \[[^]]*\] [A-Z][A-Z_]*: [^ ]* -> [^ ]* because/) {
          split($0, w, " "); key = w[3]; sub(/:$/, "", key); last[key] = w[6] "\t" $0; if (!(key in seen)) { seen[key] = 1; order[++n] = key }
        } END { for (i = 1; i <= n; i++) print order[i] "\t" last[order[i]] }' "$RUNS/config-proposals.md")
    fi

    progress="$REPO/$(progress_rel)"
    if grep -q '^## Milestones' "$REPO/prd.md" 2>/dev/null; then check_line warn milestones "milestones are still in prd.md; progress.md now holds them and prd.md only the product" "move them as procedures/repo-setup.md R2 step 5 says"
    elif [ -f "$progress" ] && ! grep -q '^## Milestones' "$progress"; then check_line warn milestones "$(progress_rel) has no Milestones section, so /idleflow:progress has nothing to count" "add one as procedures/repo-setup.md R2 step 5 says"
    elif [ -f "$progress" ]; then
      # union merge keeps both sides of a conflicting hunk, so two people ticking nearby boxes can leave an item twice
      dupes="$(awk '/^## Milestones/{m=1;next} /^## /{m=0} m && /^- \[[ x]\] /{k=$0; sub(/^- \[[ x]\] /,"",k); sub(/ \(run [^)]*\)$/,"",k); sub(/ \([0-9a-f]+\)$/,"",k); if (seen[k]++) print k}' "$progress" | head -3 | paste -sd ';' -)"
      if [ -n "$dupes" ]; then check_line warn milestones "listed twice under Milestones (a merge kept both sides): $dupes" "keep one line each in progress.md, ticked if either was"
      else check_line ok milestones "$(progress_rel) holds the milestones"; fi
    fi

    if [ "$(conventions_value docs)" = yes ]; then
      gone=()
      for f in prd.md "$(progress_rel)" "$(index_rel)"; do [ -f "$REPO/$f" ] || gone+=("$f"); done
      grep -q '<!-- idleflow start -->' "$REPO/CLAUDE.md" 2>/dev/null || gone+=("CLAUDE.md block")
      if [ "${#gone[@]}" -gt 0 ]; then check_line warn docs "missing: ${gone[*]}" "/idleflow:setup"; else check_line ok docs "prd.md, $(progress_rel), $(index_rel) and the CLAUDE.md block are present"; fi
    fi
    ;;
  conf)
    for v in DIFF_LIMIT DIFF_SLACK MAX_IMPLEMENTERS SIZE_M_IMPLEMENTERS DEBATE_ROUNDS MAX_RETRIES SIZE_S_MAX SIZE_M_MAX SIZE_S_OVERRUN LARGE_REPO_LOC STEP_DEBATE STEP_STACK STEP_LIBRARIES STEP_TOOLING STEP_DOC_KEEPER STEP_MUTATION STEP_DESIGN SLOW_GATE_SECONDS PORT_BASE; do
      echo "$v=${!v:-}"
    done
    echo "RUNTIME=$(idleflow_rt_name)"
    echo "PLUGIN_VERSION=$(plugin_version)"
    echo "REPORT_CUSTOMIZATIONS=$(report_preference)"
    ;;
  *)
    sed -n '2,44p' "$0"; exit 1;;
esac
