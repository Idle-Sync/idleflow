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
#   run.sh get <key>                      -> prints a value from run.json (dotted keys ok)
#   run.sh set <key> <json>               -> sets a value in run.json (dotted keys ok)
#   run.sh inc <key> [n]                  -> adds n (default 1) to a counter in run.json
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
#   run.sh detect                         -> suggests Repo fit and Records settings from evidence in the repo (read-only)
#   run.sh repo-gate <base|main|task-id>  -> runs the repo's approved gate there, keeps its output; exit 1 when it fails, 7 unapproved
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

# A repo can keep its records where it already keeps them (conventions "Records"). A value must be
# a plain relative path inside the repo; anything else falls back to the default, with a warning.
record_path() { # record_path <conventions key> <default>
  local v; v="$(conventions_value "$1")"
  case "$v" in ""|unset) echo "$2"; return;; esac
  if [[ "$v" =~ ^[A-Za-z0-9_][A-Za-z0-9_./-]*$ ]] && [[ "$v" != *..* ]]; then echo "${v%/}"; return; fi
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
    if [[ "$f" =~ ^[A-Za-z0-9_.*][A-Za-z0-9_.*/-]*$ ]] && [[ "$f" != *..* ]]; then echo "$f"; else echo "[idleflow] shared_files: skipped '$f'" >&2; fi
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
ensure_union_merge() {
  local f
  while IFS= read -r f; do add_ignore "$REPO/.gitattributes" "$f merge=union"; done < <(union_merge_files)
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

# Sibling by default (<repo>__wt/<task>); `worktrees_in: inside` keeps them in an ignored folder
# inside the repo, for projects that forbid writing outside their own folder.
wt_path() {
  if [ "$(conventions_value worktrees_in)" = inside ]; then echo "$IDLE/worktrees/$1"; else echo "${REPO}${SUFFIX}/$1"; fi
}

# Repo commands come from whoever pushed the repo: they run only as committed at HEAD, and only once
# this person approved that exact text (a hash in local git config; any change asks again).
REPO_COMMANDS="worktree_setup gate"
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
  if ! (cd "$2" && MAIN="$REPO" WORKTREE="$2" bash -c "$cmd") > "$log" 2>&1; then
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
{"id":"$id","worktree_setup":$(json_str "$(repo_command worktree_setup)"),"gate":$(json_str "$(repo_command gate)"),"plugin_version":$(json_str "$(plugin_version)"),"by":$(json_str "$(git config user.name || echo unknown)"),"slug":"$safe","base":$(json_str "$base"),"base_sha":"$base_sha","started":"$(date -u +%FT%TZ)","status":"planning","size":null,"tasks":{},"retries":0,"gate_trips":0,"review_findings":0}
JSON
    shared="$(shared_files | while IFS= read -r f; do json_str "$f"; echo; done | paste -sd, -)"
    echo "{\"repo\":$(json_str "$(native_path "$REPO")"),\"shared\":[${shared}],\"tasks\":{}}" > "$ACTIVE/ownership.json"
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
        tid="${1:?task-id}"; base="${2:-$(idleflow_rt get "$ACTIVE/run.json" base)}"
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
        # epoch seconds, so the retro's time log can subtract them without date parsing
        idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.t_start" "$(date +%s)"
        run_worktree_setup "$tid" "$p"
        native_path "$p"
        ;;
      rm)
        tid="${1:?task-id}"; p="$(wt_path "$tid")"
        "${G[@]}" worktree remove --force "$p" 2>/dev/null || true
        "${G[@]}" worktree prune
        ;;
      list)
        "${G[@]}" worktree list | grep '\[idleflow/' || true
        ;;
      *) echo "unknown wt subcommand" >&2; exit 1;;
    esac
    ;;
  own)
    tid="${1:?task-id}"; globs="${2:?json array}"; active_id >/dev/null
    idleflow_rt own "$ACTIVE/ownership.json" "$tid" "$(native_path "$(wt_path "$tid")")" "$globs"
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
  report)
    tid="${1:?task-id}"; active_id >/dev/null
    copy_report "$tid"
    ;;
  gate)
    tid="${1:?task-id}"; active_id >/dev/null
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
    tid="${1:?task-id}"; id="$(active_id)"
    br="idleflow/$id/$tid"; p="$(wt_path "$tid")"
    # the "never merge an unapproved task" rule, enforced here and not only in the prompt
    st="$(idleflow_rt get "$ACTIVE/run.json" "tasks.$tid.status" 2>/dev/null || true)"
    [ "$st" = "approved" ] || { echo "refusing to merge $tid: status is '${st:-unset}', not approved" >&2; exit 4; }
    # `commit_format: conventional` repos often check every subject in CI (type(scope): ..., at most
    # 72 characters), so the run id moves to the body there.
    if [ "$(conventions_value commit_format)" = conventional ]; then
      finish_msg=(-m "chore(idleflow): finish task $tid" -m "Run: $id")
      merge_msg=(-m "chore(idleflow): merge task $tid" -m "Run: $id")
    else
      finish_msg=(-m "$tid: finish task")
      merge_msg=(-m "idleflow: merge $tid ($id)")
    fi
    # commit tracked changes the implementer left uncommitted; untracked files (test caches,
    # scratch) stay out, since the reviewers already rejected anything that should have been added
    if [ -d "$p" ]; then
      git -C "$p" add -u
      git -C "$p" diff --cached --quiet || git -C "$p" ${IDENTITY[@]+"${IDENTITY[@]}"} commit -q ${finish_msg[@]+"${finish_msg[@]}"}
    fi
    if "${G[@]}" ${IDENTITY[@]+"${IDENTITY[@]}"} merge --no-ff -q "${merge_msg[@]}" "$br"; then
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
  detect)
    # Evidence for the Repo fit and Records settings, one `suggest <key>: <value> — <evidence>` line
    # for each key still unset whose evidence points away from the default. Read-only.
    unset_key() { case "$(conventions_value "$1")" in ""|unset) return 0;; *) return 1;; esac; }
    say() { echo "suggest $1: $2 — $3"; }
    if unset_key commit_format; then
      subjects="$("${G[@]}" log --no-merges -50 --format=%s 2>/dev/null || true)"
      total="$(printf '%s' "$subjects" | grep -c . || true)"
      cc="$(printf '%s\n' "$subjects" | grep -Ec '^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([A-Za-z0-9_./-]+\))?!?: ' || true)"
      if [ "${total:-0}" -ge 10 ] && [ $((cc * 100 / total)) -ge 80 ]; then say commit_format conventional "$cc of the last $total commit subjects are Conventional Commits"; fi
    fi
    if unset_key lessons_in && [ -f "$REPO/lessons.md" ] && [ ! -f "$IDLE/lessons.md" ]; then say lessons_in lessons.md "the repo already keeps lessons.md"; fi
    if unset_key progress_file && [ ! -f "$REPO/progress.md" ] && [ -f "$REPO/docs/progress.md" ]; then say progress_file docs/progress.md "the repo keeps docs/progress.md"; fi
    if unset_key session_names; then
      dir="$REPO/$(sessions_rel)"
      [ -d "$dir" ] || dir="$REPO/docs/sessions"
      people="$("${G[@]}" log --format='%ae' 2>/dev/null | sort -u | wc -l | tr -d ' ')"
      if ls "$dir"/*/ 2>/dev/null | grep -qE '^s_[0-9]{4}\.md$'; then say session_names per-person "notes in ${dir#"$REPO"/} are already in one folder per person"
      elif ls "$dir" 2>/dev/null | grep -qE '^s_[0-9]{4}\.md$'; then
        if [ "${people:-1}" -gt 1 ]; then say session_names per-person "notes are numbered s_NNNN.md and $people people commit here; a folder per person keeps the numbering without collisions"
        else say session_names numbered "$(ls "$dir" | grep -cE '^s_[0-9]{4}\.md$') notes in ${dir#"$REPO"/} are numbered s_NNNN.md"; fi
      fi
    fi
    if unset_key index_rewrite && [ -f "$REPO/$(index_rel)" ] && ! grep -q "Rewritten by the idleflow retro" "$REPO/$(index_rel)"; then
      say index_rewrite no "$(index_rel) was not written by idleflow, so the repo keeps it its own way"
    fi
    if unset_key shared_files; then
      shared=()
      grep -qiE '^## \[?unreleased' "$REPO/CHANGELOG.md" 2>/dev/null && shared+=(CHANGELOG.md)
      [ "$(conventions_value index_rewrite)" = no ] && [ -f "$REPO/$(index_rel)" ] && shared+=("$(index_rel)")
      [ "${#shared[@]}" -gt 0 ] && say shared_files "${shared[*]}" "every change adds a line here (an Unreleased changelog section, an index the repo keeps itself)"
    fi
    if unset_key worktrees_in && grep -qiE '(outside|beyond) (of )?(this|the) (folder|directory|repo|repository|project)' "$REPO/CLAUDE.md" 2>/dev/null; then
      say worktrees_in inside "CLAUDE.md forbids working outside this folder"
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
    # The repo's own check, the definition of done: on the run's base before building (so earlier
    # breakage is not blamed on the run), in a task's worktree, or on the main checkout after merge.
    target="${1:?base|main|<task-id>}"; active_id >/dev/null
    cmd="$(idleflow_rt get "$ACTIVE/run.json" gate 2>/dev/null || true)"
    case "$cmd" in ""|null) echo "repo gate: none"; exit 0;; esac
    command_approved gate "$cmd" || { echo "gate is not approved on this clone; nothing ran. The command is: $cmd" >&2; exit 7; }
    case "$target" in
      base|main) dir="$REPO"; log="$ACTIVE/repo-gate-$target.log";;
      *) dir="$(wt_path "$target")"; log="$ACTIVE/tasks/$target/repo-gate.log"; mkdir -p "$ACTIVE/tasks/$target"
         [ -d "$dir" ] || { echo "repo-gate: no worktree for $target" >&2; exit 1; };;
    esac
    if [ "$target" = base ] && [ -n "$("${G[@]}" status --porcelain --untracked-files=no)" ]; then
      echo "repo-gate base: the main checkout has uncommitted changes, so it is not the base; commit or stash them first" >&2; exit 1
    fi
    echo "repo gate ($target): $cmd" >&2
    set +e
    (cd "$dir" && MAIN="$REPO" bash -c "$cmd") > "$log" 2>&1
    rc=$?
    set -e
    echo "repo gate $target: exit $rc (full output: $(native_path "$log"))"
    tail -15 "$log"
    [ "$rc" -eq 0 ] || exit 1
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
    key="${1:?worktree_setup|gate}"
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
    people="$("${G[@]}" log --format='%ae' 2>/dev/null | sort -u | wc -l | tr -d ' ')"
    if grep -q '"idleflow@idlesync"' "$REPO/.claude/settings.json" 2>/dev/null; then check_line ok team ".claude/settings.json recommends idleflow to everyone who opens the repo"
    elif [ "${people:-0}" -gt 1 ]; then check_line warn team "$people people commit here, but .claude/settings.json does not recommend idleflow, so teammates work without it" "run.sh team-install"
    else check_line ok team "one contributor so far (run.sh team-install when others join)"; fi
    union_missing=""
    # only files that exist yet: a log no run has written cannot conflict, and snapshot adds its rule anyway
    while IFS= read -r f; do [ -e "$REPO/$f" ] || continue; grep -qxF "$f merge=union" "$REPO/.gitattributes" 2>/dev/null || union_missing="$union_missing $f"; done < <(union_merge_files)
    if [ -n "$union_missing" ]; then check_line warn merges "no union merge for:$union_missing, so concurrent entries conflict" "run.sh snapshot"; else check_line ok merges "lessons, progress and suggestions merge without conflicts"; fi

    while IFS= read -r line; do
      case "$line" in
        approved\ *) check_line ok commands "${line#approved }";;
        unapproved\ *) key="${line#unapproved }"; key="${key%%:*}"
          check_line warn commands "not approved by you yet, so it never runs: ${line#unapproved }" "read the command, then run.sh approve $key";;
      esac
    done <<< "$(bash "$0" commands 2>/dev/null || true)"

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
      grep -qF -- "- declined: $key -> $val " "$IDLE/suggestions.md" 2>/dev/null && continue
      check_line suggest "fit $key" "$val (${rest#* — })" "/idleflow:setup, which asks before changing anything"
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
    for v in DIFF_LIMIT DIFF_SLACK MAX_IMPLEMENTERS SIZE_M_IMPLEMENTERS DEBATE_ROUNDS MAX_RETRIES SIZE_S_MAX SIZE_M_MAX SIZE_S_OVERRUN LARGE_REPO_LOC STEP_DEBATE STEP_STACK STEP_LIBRARIES STEP_TOOLING STEP_DOC_KEEPER STEP_MUTATION; do
      echo "$v=${!v:-}"
    done
    echo "RUNTIME=$(idleflow_rt_name)"
    echo "PLUGIN_VERSION=$(plugin_version)"
    echo "REPORT_CUSTOMIZATIONS=$(report_preference)"
    ;;
  *)
    sed -n '2,42p' "$0"; exit 1;;
esac
