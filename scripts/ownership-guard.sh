#!/usr/bin/env bash
# PreToolUse hook on Edit|Write|MultiEdit|NotebookEdit.
#
# Reads the hook payload from stdin, finds the active run's ownership map
# (.claude/runs/active/ownership.json in the main repo), and blocks any edit to a
# file inside a task worktree that the task does not own.
#
# Exit 0  -> allow.   Exit 2 -> block; stderr goes back to the agent as the reason.
#
# ownership.json shape:
# {
#   "repo": "/abs/path/to/repo",
#   "tasks": {
#     "T1": { "worktree": "/abs/path/repo__wt/T1", "owns": ["src/auth/**", "tests/auth/**"] },
#     ...
#   }
# }
#
# Files outside any listed worktree are allowed (the orchestrator edits plan.md etc.
# in the main checkout). Files inside a worktree must match one of that task's globs
# (fnmatch style: `*` also crosses `/`). A missing or unparsable map allows
# everything, and so does a missing runtime — the guard must never brick a session.
#
# The check itself lives in idleflow.py / idleflow.js (`guard` subcommand); rt.sh picks
# whichever of Python or Node is installed. Paths are normalised there, so Windows
# (D:\x, D:/x, /d/x) and POSIX paths all compare correctly.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/rt.sh"

idleflow_rt guard
rc=$?
[ "$rc" -eq 2 ] && exit 2
exit 0
