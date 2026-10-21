#!/usr/bin/env bash
# Run lifecycle helper. Called by the orchestrator (the /idleflow:* commands).
# Everything is plain git + files so a run can be inspected or resumed by hand.
#
#   run.sh new <slug>                     -> creates .claude/runs/active/ for a new run, prints its <id>
#   run.sh wt add <task-id> [base-ref]    -> creates worktree <repo>__wt/<task-id> on branch idleflow/<run-id>/<task-id>,
#                                            records the task's base sha in run.json, prints the worktree path
#   run.sh wt rm <task-id>                -> removes the worktree (keeps the branch); works with or without an active run
#   run.sh wt list                        -> lists idleflow worktrees
#   run.sh own <task-id> '<globs json>'   -> registers file ownership for the guard hook
#   run.sh get <key>                      -> prints a value from run.json (dotted keys ok)
#   run.sh set <key> <json>               -> sets a value in run.json (dotted keys ok)
#   run.sh inc <key> [n]                  -> adds n (default 1) to a counter in run.json
#   run.sh report <task-id>               -> copies the task's .claude-run/report.md into the run dir, prints its path
#   run.sh gate <task-id> [limit]         -> runs diff-gate against the task's own base, writes tasks/<id>/gate.json, prints it
#   run.sh merge <task-id>                -> merges the task branch into the current branch (no-ff); exit 3 on conflict
#   run.sh snapshot                       -> commits the repo-level docs the orchestrator writes (conventions, CLAUDE.md, prd, ...)
#   run.sh finish [status]                -> logs the run to .claude/runs/log.jsonl, renames active/ to <id>/
#   run.sh loc                            -> prints hand-written code lines in the repo (DIFF_EXCLUDE applied)
#   run.sh conf                           -> prints resolved config values and the runtime in use
#
# The active run lives in .claude/runs/active/ (a real directory, no symlinks, so it
# works on Windows). `finish` renames it to .claude/runs/<id>/. JSON work is done by
# scripts/idleflow.py or idleflow.js through rt.sh, whichever runtime is installed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${IDLEFLOW_CONF:-$HERE/../config/idleflow.conf}"
# shellcheck source=/dev/null
[ -f "$CONF" ] && source "$CONF"
# shellcheck source=/dev/null
source "$HERE/rt.sh"

REPO="$(git rev-parse --show-toplevel)"
RUNS="$REPO/.claude/runs"
ACTIVE="$RUNS/active"
SUFFIX="${WORKTREE_SUFFIX:-__wt}"
IDENTITY=(-c user.name=idleflow -c user.email=idleflow@local)

# Paths handed to agents or written to JSON are native (D:/x on Windows, unchanged elsewhere).
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

active_id() {
  [ -f "$ACTIVE/run.json" ] || { echo "no active run (run.sh new <slug> first)" >&2; exit 1; }
  idleflow_rt get "$ACTIVE/run.json" id
}

wt_path() { echo "${REPO}${SUFFIX}/$1"; }

# Build the DIFF_EXCLUDE pathspec list into EXCL[].
build_excl() {
  EXCL=()
  while IFS= read -r pat; do [ -z "$pat" ] && continue; EXCL+=(":(glob,exclude)$pat"); done <<< "${DIFF_EXCLUDE:-}"
}

# Move a leftover active/ aside under its own id so a new run can start.
park_active() {
  [ -d "$ACTIVE" ] || return 0
  local old
  old="$(idleflow_rt get "$ACTIVE/run.json" id 2>/dev/null || echo "abandoned-$(date +%Y%m%d-%H%M%S)")"
  if [ -f "$ACTIVE/run.json" ]; then
    idleflow_rt set "$ACTIVE/run.json" status '"abandoned"' || true
  fi
  rm -rf "$RUNS/$old"
  mv "$ACTIVE" "$RUNS/$old"
  echo "parked unfinished run as .claude/runs/$old" >&2
}

# Copy a task's report out of its worktree (the worktree is deleted at the end of the run).
copy_report() {
  local tid="$1" src dst
  src="$(wt_path "$tid")/.claude-run/report.md"; dst="$ACTIVE/tasks/$tid/report.md"
  mkdir -p "$ACTIVE/tasks/$tid"
  [ -f "$src" ] && cp "$src" "$dst"
  echo "$(native_path "$dst")"
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
    base="$(git symbolic-ref --short -q HEAD || echo HEAD)"
    base_sha="$(git rev-parse -q --verify HEAD 2>/dev/null || true)"
    cat > "$ACTIVE/run.json" <<JSON
{"id":"$id","slug":"$safe","base":"$base","base_sha":"$base_sha","started":"$(date -u +%FT%TZ)","status":"planning","size":null,"tasks":{},"retries":0,"gate_trips":0,"review_findings":0}
JSON
    echo '{"repo":"'"$(native_path "$REPO")"'","tasks":{}}' > "$ACTIVE/ownership.json"
    grep -qxF '.claude/runs/' "$REPO/.gitignore" 2>/dev/null || echo '.claude/runs/' >> "$REPO/.gitignore"
    # worktree marker dir: excluded locally (shared by all worktrees), never committed or merged
    excl="$(git rev-parse --git-common-dir)/info/exclude"; mkdir -p "$(dirname "$excl")"
    grep -qxF '.claude-run/' "$excl" 2>/dev/null || echo '.claude-run/' >> "$excl"
    echo "$id"
    ;;
  wt)
    sub="${1:?add|rm|list}"; shift || true
    case "$sub" in
      add)
        id="$(active_id)"
        tid="${1:?task-id}"; base="${2:-$(idleflow_rt get "$ACTIVE/run.json" base)}"
        p="$(wt_path "$tid")"; br="idleflow/$id/$tid"
        git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "base '$base' has no commits yet; commit first (run.sh snapshot)" >&2; exit 1; }
        # a leftover from a crashed run must not make `add` fail
        git worktree prune
        if [ -d "$p" ]; then git worktree remove --force "$p" 2>/dev/null || true; case "$p" in *"$SUFFIX"/*) rm -rf "$p";; esac; fi
        mkdir -p "$(dirname "$p")"
        git worktree add -B "$br" "$p" "$base" >/dev/null
        mkdir -p "$p/.claude-run" "$ACTIVE/tasks/$tid"
        echo "$tid" > "$p/.claude-run/task-id"
        native_path "$REPO" > "$p/.claude-run/repo"   # lets the guard hook find the ownership map from inside the worktree
        # the task's own base: groups merged earlier move the branch, so gate/review must diff from here, not from the run start
        idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.base_sha" "\"$(git rev-parse "$base")\""
        idleflow_rt set "$ACTIVE/run.json" "tasks.$tid.worktree" "\"$(native_path "$p")\""
        native_path "$p"
        ;;
      rm)
        tid="${1:?task-id}"; p="$(wt_path "$tid")"
        git worktree remove --force "$p" 2>/dev/null || true
        git worktree prune
        ;;
      list)
        git worktree list | grep "idleflow/" || true
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
    base="$(idleflow_rt get "$ACTIVE/run.json" "tasks.$tid.base_sha" 2>/dev/null || idleflow_rt get "$ACTIVE/run.json" base_sha)"
    out="$("$HERE/diff-gate.sh" "$(wt_path "$tid")" "$base" ${2:+"$2"})"
    mkdir -p "$ACTIVE/tasks/$tid"
    echo "$out" > "$ACTIVE/tasks/$tid/gate.json"
    copy_report "$tid" >/dev/null
    echo "$out"
    ;;
  merge)
    tid="${1:?task-id}"; id="$(active_id)"
    br="idleflow/$id/$tid"
    # commit anything the implementer left uncommitted in the worktree
    ( cd "$(wt_path "$tid")" && git add -A && git "${IDENTITY[@]}" commit -qm "$tid: finish task" || true )
    if git -C "$REPO" "${IDENTITY[@]}" merge --no-ff -q -m "idleflow: merge $tid ($id)" "$br"; then
      echo "merged $tid"
    elif [ -f "$(git -C "$REPO" rev-parse --git-dir)/MERGE_HEAD" ]; then
      git -C "$REPO" merge --abort || true
      echo "CONFLICT merging $tid — resolve by re-running the owning task against the new base, or merge by hand" >&2
      exit 3
    else
      echo "merge of $tid failed before any conflict (dirty checkout? unknown branch $br?)" >&2
      exit 4
    fi
    ;;
  snapshot)
    # The orchestrator creates repo-level docs in the main checkout before any worktree exists.
    # Commit them so worktrees (branched from HEAD) see them and nothing is left dangling.
    cd "$REPO"
    for f in .claude/conventions.md .claude/lessons.md CLAUDE.md prd.md progress.md index.md README.md .gitignore .gitattributes docs; do
      [ -e "$f" ] && git add -A -- "$f"
    done
    if git diff --cached --quiet 2>/dev/null; then
      echo "snapshot: nothing to commit"
    else
      git "${IDENTITY[@]}" commit -qm "docs: project conventions and run inputs"
      echo "snapshot: committed $(git rev-parse --short HEAD)"
    fi
    ;;
  finish)
    status="${1:-done}"; id="$(active_id)"
    idleflow_rt finish "$ACTIVE/run.json" "$status" "$RUNS/log.jsonl"
    rm -rf "$RUNS/$id"
    mv "$ACTIVE" "$RUNS/$id"
    echo "run $id finished: $status"
    ;;
  loc)
    # Hand-written code lines in the repo: tracked files minus DIFF_EXCLUDE. Docs don't count.
    build_excl
    n="$(git -C "$REPO" ls-files -z -- . ${EXCL[@]+"${EXCL[@]}"} | xargs -0 -r cat 2>/dev/null | wc -l | tr -d ' ')"
    echo "${n:-0}"
    ;;
  conf)
    for v in DIFF_LIMIT DIFF_SLACK MAX_IMPLEMENTERS SIZE_M_IMPLEMENTERS DEBATE_ROUNDS MAX_RETRIES SIZE_S_MAX SIZE_M_MAX SIZE_S_OVERRUN LARGE_REPO_LOC; do
      echo "$v=${!v:-}"
    done
    echo "RUNTIME=$(idleflow_rt_name)"
    ;;
  *)
    sed -n '2,21p' "$0"; exit 1;;
esac
