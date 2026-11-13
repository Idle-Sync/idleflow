#!/usr/bin/env bash
# PreToolUse hook on Bash.
#
# Inside an idleflow run (the session's project folder or its cwd is the main checkout of an active
# run, or one of its task worktrees),
# refuses a command that ends processes by name or pattern (pkill, killall, kill $(pgrep ...),
# pgrep ... | xargs kill, fuser -k): those match every process on the machine with that text,
# including other Claude Code sessions' work. A kill by a PID the agent kept is allowed. A plugin's
# hooks run in every session, so outside a run every command is allowed, as the ownership guard does.
#
# Exit 0 -> allow. Exit 2 -> block; stderr goes back to the agent as the reason. A missing runtime
# allows everything: the guard must never brick a session. The check lives in idleflow.py /
# idleflow.js (`killguard` subcommand).

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/rt.sh"

idleflow_rt killguard
rc=$?
[ "$rc" -eq 2 ] && exit 2
exit 0
