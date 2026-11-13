#!/usr/bin/env bash
# Count hand-written code lines a task's commits change against a base ref (base..HEAD, what
# would merge) and emit a JSON verdict. Never fails the run itself; the orchestrator reads the JSON.
# Uncommitted files in the worktree (a setup script's generated output, a test cache) never count:
# they are listed under "uncommitted" so a task that forgot to commit is still visible.
#
# Usage: diff-gate.sh <worktree-path> <base-ref> [limit] [slack]
# Output (stdout, single line JSON):
#   {"added":N,"deleted":N,"total":N,"files":N,"limit":N,"slack":N,
#    "verdict":"ok|audit|split","excluded_total":N,"top":[["path",lines],...],
#    "uncommitted":N,"uncommitted_paths":["path",...]}
#
# verdict:
#   ok    -> total <= limit                 (no auditor)
#   audit -> limit < total <= limit+slack   (auditor runs, default accept)
#   split -> total > limit+slack            (auditor runs, default split)

set -euo pipefail

WT="${1:?worktree path}"
BASE="${2:?base ref}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/rt.sh"
# shellcheck source=/dev/null
source "$HERE/conf.sh"
# The project's settings come from the task's base commit: a task must not raise its own limit
# by editing .idleflow/idleflow.conf in the worktree being gated.
BASE_CONF="$(mktemp)"; trap 'rm -f "$BASE_CONF"' EXIT
git -C "$WT" show "$BASE:.idleflow/idleflow.conf" > "$BASE_CONF" 2>/dev/null || : > "$BASE_CONF"
idleflow_load_conf "" "$BASE_CONF"
LIMIT="${3:-${DIFF_LIMIT:-1500}}"
SLACK="${4:-${DIFF_SLACK:-300}}"

[ -d "$WT" ] || { echo "{\"error\":\"no worktree at $WT\"}"; exit 1; }
cd "$WT"
# A wrong base must not pass as "0 lines changed, ok".
git rev-parse -q --verify "$BASE^{commit}" >/dev/null 2>&1 || { echo "{\"error\":\"bad base $BASE\"}"; exit 1; }

# Build pathspec exclusions
EXCL=()
while IFS= read -r pat; do
  [ -z "$pat" ] && continue
  EXCL+=(":(glob,exclude)$pat")
done <<< "${DIFF_EXCLUDE:-}"

# numstat goes through files, not argv: a big diff would overflow the Windows
# command-line limit. The index is never touched: the gate reads, it does not stage.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp" "$BASE_CONF"' EXIT
git diff --numstat "$BASE" HEAD -- . > "$tmp/all" 2>/dev/null || true
git diff --numstat "$BASE" HEAD -- . ${EXCL[@]+"${EXCL[@]}"} > "$tmp/code" 2>/dev/null || true
git status --porcelain -- . ':(exclude).idleflow-run' 2>/dev/null | cut -c4- > "$tmp/uncommitted" || true

idleflow_rt gate "$LIMIT" "$SLACK" "$tmp/all" "$tmp/code" "$tmp/uncommitted"
