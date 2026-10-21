#!/usr/bin/env bash
# Run lifecycle helper. Called by the orchestrator (the /idleflow:* commands).
# Everything is plain git + files so a run can be inspected or resumed by hand.
#
#   run.sh new <slug>                     -> creates .claude/runs/active/ for a new run, prints its <id>
#   run.sh wt add <task-id> [base-ref]    -> creates worktree <repo>__wt/<task-id> on branch idleflow/<run-id>/<task-id>
#   run.sh wt rm <task-id>                -> removes the worktree (keeps the branch)
#   run.sh wt list                        -> lists worktrees for the active run
#   run.sh own <task-id> '<globs json>'   -> registers file ownership for the guard hook
#   run.sh set <key> <json>               -> sets a value in run.json (dotted keys ok)
#   run.sh inc <key> [n]                  -> adds n (default 1) to a counter in run.json
#   run.sh gate <task-id>                 -> runs diff-gate on that task's worktree, writes tasks/<id>/gate.json, prints it
#   run.sh merge <task-id>                -> merges the task branch into the current branch (no-ff), aborts on conflict
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

# Paths handed to agents or written to JSON are native (D:/x on Windows, unchanged elsewhere).
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

active_id() {
  [ -f "$ACTIVE/run.json" ] || { echo "no active run (run.sh new <slug> first)" >&2; exit 1; }
  idleflow_rt get "$ACTIVE/run.json" id
}

wt_path() { echo "${REPO}${WORKTREE_SUFFIX:-__wt}/$1"; }

# Move a leftover active/ aside under its own id so a new run can start.
park_active() {
  [ -d "$ACTIVE" ] || return 0
  local old
  old="$(idleflow_rt get "$ACTIVE/run.json" id 2>/dev/null || echo "abandoned-$(date +%Y%m%d-%H%M%S)")"
  if [ -f "$ACTIVE/run.json" ]; then
    idleflow_rt set "$ACTIVE/run.json" status '"abandoned"' || true
  fi
  mv "$ACTIVE" "$RUNS/$old"
  echo "parked unfinished run as .claude/runs/$old" >&2
}

cmd="${1:-}"; shift || true
case "$cmd" in
  new)
    slug="${1:?slug}"
    id="$(date +%Y%m%d-%H%M%S)-$(echo "$slug" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-40)"
    mkdir -p "$RUNS"
    park_active
    mkdir -p "$ACTIVE"/{tasks,debate,review}
    base="$(git rev-parse --abbrev-ref HEAD)"
    cat > "$ACTIVE/run.json" <<JSON
{"id":"$id","slug":"$slug","base":"$base","base_sha":"$(git rev-parse HEAD)","started":"$(date -u +%FT%TZ)","status":"planning","size":null,"tasks":{},"retries":0,"gate_trips":0,"review_findings":0}
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
    id="$(active_id)"
    case "$sub" in
      add)
        tid="${1:?task-id}"; base="${2:-$(idleflow_rt get "$ACTIVE/run.json" base)}"
        p="$(wt_path "$tid")"; br="idleflow/$id/$tid"
        mkdir -p "$(dirname "$p")"
        git worktree add -B "$br" "$p" "$base" >/dev/null
        mkdir -p "$p/.claude-run" "$ACTIVE/tasks/$tid"
        echo "$tid" > "$p/.claude-run/task-id"
        native_path "$REPO" > "$p/.claude-run/repo"   # lets the guard hook find the ownership map from inside the worktree
        native_path "$p"
        ;;
      rm)
        tid="${1:?task-id}"; p="$(wt_path "$tid")"
        git worktree remove --force "$p" 2>/dev/null || true
        ;;
      list)
        git worktree list | grep "idleflow/$id/" || true
        ;;
      *) echo "unknown wt subcommand" >&2; exit 1;;
    esac
    ;;
  own)
    tid="${1:?task-id}"; globs="${2:?json array}"; active_id >/dev/null
    idleflow_rt own "$ACTIVE/ownership.json" "$tid" "$(native_path "$(wt_path "$tid")")" "$globs"
    ;;
  set)
    key="${1:?key}"; val="${2:?json value}"; active_id >/dev/null
    idleflow_rt set "$ACTIVE/run.json" "$key" "$val"
    ;;
  inc)
    key="${1:?key}"; n="${2:-1}"; active_id >/dev/null
    idleflow_rt inc "$ACTIVE/run.json" "$key" "$n"
    ;;
  gate)
    tid="${1:?task-id}"; active_id >/dev/null
    base="$(idleflow_rt get "$ACTIVE/run.json" base_sha)"
    out="$("$HERE/diff-gate.sh" "$(wt_path "$tid")" "$base")"
    mkdir -p "$ACTIVE/tasks/$tid"
    echo "$out" > "$ACTIVE/tasks/$tid/gate.json"
    echo "$out"
    ;;
  merge)
    tid="${1:?task-id}"; id="$(active_id)"
    br="idleflow/$id/$tid"
    # commit anything the implementer left uncommitted in the worktree
    ( cd "$(wt_path "$tid")" && git add -A && git -c user.name=idleflow -c user.email=idleflow@local commit -qm "idleflow: $tid" || true )
    if git merge --no-ff -q -m "idleflow: merge $tid ($id)" "$br"; then
      echo "merged $tid"
    else
      git merge --abort || true
      echo "CONFLICT merging $tid — resolve by re-running the owning task against the new base, or merge by hand" >&2
      exit 3
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
    EXCL=()
    while IFS= read -r pat; do [ -z "$pat" ] && continue; EXCL+=(":(glob,exclude)$pat"); done <<< "${DIFF_EXCLUDE:-}"
    n="$(git -C "$REPO" ls-files -z -- . "${EXCL[@]}" | xargs -0 -r cat 2>/dev/null | wc -l | tr -d ' ')"
    echo "${n:-0}"
    ;;
  conf)
    for v in DIFF_LIMIT DIFF_SLACK MAX_IMPLEMENTERS DEBATE_ROUNDS MAX_RETRIES SIZE_S_MAX SIZE_M_MAX SIZE_S_OVERRUN LARGE_REPO_LOC; do
      echo "$v=${!v:-}"
    done
    echo "RUNTIME=$(idleflow_rt_name)"
    ;;
  *)
    sed -n '2,15p' "$0"; exit 1;;
esac
