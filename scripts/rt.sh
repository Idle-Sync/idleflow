#!/usr/bin/env bash
# Runtime picker. Sourced by run.sh, diff-gate.sh and ownership-guard.sh.
#
#   idleflow_rt <subcommand> [args...]
#
# Runs scripts/idleflow.py or scripts/idleflow.js (same program, two languages)
# on whichever runtime is available:
#   1. $IDLEFLOW_RUNTIME if set: python | python3 | node (or a full path to the binary)
#   2. python3, then python  (must be >= 3.8; the Windows Store stub fails the check)
#   3. node                  (>= 18)
# Exit 127 with a message if none is found. The caller decides whether that is fatal.

_IDLEFLOW_RT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_idleflow_py_ok() { "$1" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' </dev/null >/dev/null 2>&1; }

idleflow_rt() {
  local py
  case "${IDLEFLOW_RUNTIME:-}" in
    "") ;;
    node|*/node|*/node.exe|node.exe) node "$_IDLEFLOW_RT_DIR/idleflow.js" "$@"; return ;;
    *) "${IDLEFLOW_RUNTIME}" -I "$_IDLEFLOW_RT_DIR/idleflow.py" "$@"; return ;;
  esac
  for py in python3 python; do
    if command -v "$py" >/dev/null 2>&1 && _idleflow_py_ok "$py"; then
      "$py" -I "$_IDLEFLOW_RT_DIR/idleflow.py" "$@"; return
    fi
  done
  if command -v node >/dev/null 2>&1; then
    node "$_IDLEFLOW_RT_DIR/idleflow.js" "$@"; return
  fi
  echo "[idleflow] no runtime: install Python >= 3.8 or Node >= 18, or set IDLEFLOW_RUNTIME" >&2
  return 127
}

# Prints which runtime idleflow_rt would use. Used by `run.sh conf` and selftest.
idleflow_rt_name() {
  local py
  case "${IDLEFLOW_RUNTIME:-}" in
    "") ;;
    node|*/node|*/node.exe|node.exe) echo "node ($(node --version 2>/dev/null))"; return ;;
    *) echo "${IDLEFLOW_RUNTIME} ($("${IDLEFLOW_RUNTIME}" --version 2>&1 | head -1))"; return ;;
  esac
  for py in python3 python; do
    if command -v "$py" >/dev/null 2>&1 && _idleflow_py_ok "$py"; then
      echo "$py ($("$py" --version 2>&1 | head -1))"; return
    fi
  done
  if command -v node >/dev/null 2>&1; then echo "node ($(node --version))"; return; fi
  echo "none"
}
