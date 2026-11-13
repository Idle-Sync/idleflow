#!/usr/bin/env bash
# PreToolUse hook on Bash.
#
# Refuses a command that ends processes by name or pattern (pkill, killall, kill $(pgrep ...),
# pgrep ... | xargs kill, fuser -k): those match every process on the machine with that text,
# including other Claude Code sessions' work. A kill by a PID the agent kept is allowed.
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
