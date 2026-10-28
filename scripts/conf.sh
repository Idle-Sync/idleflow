#!/usr/bin/env bash
# Config loader. Sourced by run.sh and diff-gate.sh.
#
#   idleflow_load_conf <repo-root>   -> the plugin's config/idleflow.conf, then <repo-root>/.idleflow/idleflow.conf on top
#   idleflow_conf_valid <key> <value> -> true when the project file may set that key to that value
#
# The project file is committed, so it comes from whoever pushed to the repo: it is parsed,
# never sourced, and only the keys below with plain values are taken. Anything else is
# reported on stderr and skipped; `run.sh doctor` lists those lines.

_IDLEFLOW_CONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_idleflow_number_in() { # _idleflow_number_in <value> <min> <max>
  local re='^[0-9]+$'
  [[ "$1" =~ $re ]] && [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]
}

idleflow_conf_valid() {
  local agent_re='^[A-Z][A-Z_]*$' version_re='^[0-9]+\.[0-9]+\.[0-9]+$' globs_re='^[A-Za-z0-9_.*/-]+( [A-Za-z0-9_.*/-]+)*$'
  case "$1" in
    DIFF_LIMIT|SIZE_S_MAX|SIZE_M_MAX|SIZE_S_OVERRUN|LARGE_REPO_LOC) _idleflow_number_in "$2" 1 100000000 ;;
    DIFF_SLACK) _idleflow_number_in "$2" 0 100000000 ;;
    MAX_IMPLEMENTERS|SIZE_M_IMPLEMENTERS) _idleflow_number_in "$2" 1 8 ;;
    DEBATE_ROUNDS) _idleflow_number_in "$2" 1 2 ;;
    MAX_RETRIES) _idleflow_number_in "$2" 0 3 ;;
    STEP_DEBATE|STEP_STACK|STEP_LIBRARIES|STEP_TOOLING|STEP_DOC_KEEPER)
      case "$2" in auto|on|off) ;; *) return 1;; esac ;;
    MODEL_*) [[ "${1#MODEL_}" =~ $agent_re ]] && case "$2" in haiku|sonnet|opus|fable) ;; *) return 1;; esac ;;
    REPLACED_*) [[ "${1#REPLACED_}" =~ $agent_re ]] && [[ "$2" =~ $version_re ]] ;;
    REPORT_CUSTOMIZATIONS) case "$2" in ask|always|never) ;; *) return 1;; esac ;;
    DIFF_EXCLUDE_ADD) [[ "$2" =~ $globs_re ]] ;;
    *) return 1 ;;
  esac
}

idleflow_load_conf() {
  local defaults="${IDLEFLOW_CONF:-$_IDLEFLOW_CONF_DIR/../config/idleflow.conf}" project line key val
  # shellcheck source=/dev/null
  [ -f "$defaults" ] && source "$defaults"
  project="${1:-}/.idleflow/idleflow.conf"
  [ -n "${1:-}" ] && [ -f "$project" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ""|\#*) continue;; esac
    key="${line%%=*}"; val="${line#*=}"
    if [ "$key" != "$line" ] && idleflow_conf_valid "$key" "$val"; then
      printf -v "$key" '%s' "$val"
    else
      echo "[idleflow] ignored in .idleflow/idleflow.conf: $line" >&2
    fi
  done < "$project"
  if [ -n "${DIFF_EXCLUDE_ADD:-}" ]; then DIFF_EXCLUDE="${DIFF_EXCLUDE:-}"$'\n'"$(tr ' ' '\n' <<< "$DIFF_EXCLUDE_ADD")"; fi
  return 0
}
