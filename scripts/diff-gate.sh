#!/usr/bin/env bash
# Count hand-written code lines changed in a worktree against a base ref and
# emit a JSON verdict. Never fails the run itself; the orchestrator reads the JSON.
#
# Usage: diff-gate.sh <worktree-path> <base-ref> [limit] [slack]
# Output (stdout, single line JSON):
#   {"added":N,"deleted":N,"total":N,"files":N,"limit":N,"slack":N,
#    "verdict":"ok|audit|split","excluded_total":N,"top":[["path",lines],...]}
#
# verdict:
#   ok    -> total <= limit                 (no auditor)
#   audit -> limit < total <= limit+slack   (auditor runs, default accept)
#   split -> total > limit+slack            (auditor runs, default split)

set -euo pipefail

WT="${1:?worktree path}"
BASE="${2:?base ref}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${IDLEFLOW_CONF:-$HERE/../config/idleflow.conf}"
# shellcheck source=/dev/null
[ -f "$CONF" ] && source "$CONF"
# shellcheck source=/dev/null
source "$HERE/rt.sh"
LIMIT="${3:-${DIFF_LIMIT:-1500}}"
SLACK="${4:-${DIFF_SLACK:-300}}"

cd "$WT"

# Build pathspec exclusions
EXCL=()
while IFS= read -r pat; do
  [ -z "$pat" ] && continue
  EXCL+=(":(glob,exclude)$pat")
done <<< "${DIFF_EXCLUDE:-}"

# Stage untracked files so numstat sees them (does not commit).
git add -A -N . 2>/dev/null || true

# numstat goes through files, not argv: a big diff would overflow the Windows
# command-line limit.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git diff --numstat "$BASE" -- . > "$tmp/all" 2>/dev/null || true
git diff --numstat "$BASE" -- . ${EXCL[@]+"${EXCL[@]}"} > "$tmp/code" 2>/dev/null || true

idleflow_rt gate "$LIMIT" "$SLACK" "$tmp/all" "$tmp/code"
