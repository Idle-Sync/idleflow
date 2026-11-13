#!/usr/bin/env bash
# Usage: bash scripts/shellcheck-new.sh <base-ref>
#
# Runs shellcheck on every tracked *.sh file at HEAD and at <base-ref>, and fails only on findings
# HEAD has that the base does not. A finding is its file, level, message and code; line numbers are
# left out, so a finding that only moved is not new, and a branch is judged by what it adds.
#
# Exit 0 -> nothing new. Exit 1 -> new findings: each kind with how many more HEAD has, and the
# lines of each kind the base has none of.
# Exit 2 -> bad usage, or shellcheck is missing or cannot check a file.

set -euo pipefail
base="${1:?usage: shellcheck-new.sh <base-ref>}"
command -v shellcheck >/dev/null || { echo "shellcheck-new: shellcheck is not installed" >&2; exit 2; }
git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "shellcheck-new: '$base' is not a commit" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)"

work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT

# gcc-format findings for the given files, run from folder $1 so paths read the same on both sides
check() { # check <folder> <file...>
  local dir="$1" rc=0; shift
  [ "$#" -gt 0 ] || return 0
  (cd "$dir" && shellcheck -f gcc "$@") || rc=$?
  # 1 means it found something; anything higher means it could not check
  [ "$rc" -le 1 ] || { echo "shellcheck-new: shellcheck failed ($rc) in $dir" >&2; exit 2; }
}
# file: level: message [code], one per finding, sorted, so the two sides can be compared by count
keys() { sed -E 's/^([^:]+):[0-9]+:[0-9]+: /\1: /' | LC_ALL=C sort; }

mapfile -t now < <(git ls-files -- '*.sh')
# the base's files, each under its name at HEAD when it was renamed since, so its findings match
mapfile -t was < <(git ls-tree -r --name-only "$base" | grep '\.sh$' || true)
declare -A renamed=()
while IFS=$'\t' read -r status old new; do
  case "$status" in R*) renamed["$old"]="$new";; esac
done < <(git diff --name-status -M "$base" HEAD)
mkdir -p "$work/base"
names=()
for f in ${was[@]+"${was[@]}"}; do
  to="${renamed[$f]:-$f}"
  mkdir -p "$work/base/$(dirname "$to")"
  git show "$base:$f" > "$work/base/$to"
  names+=("$to")
done

check . ${now[@]+"${now[@]}"} > "$work/head.txt"
check "$work/base" ${names[@]+"${names[@]}"} > "$work/base.txt"
keys < "$work/head.txt" > "$work/head.keys"
keys < "$work/base.txt" > "$work/base.keys"

# the keys HEAD has more often than the base, once for each extra one
LC_ALL=C comm -23 "$work/head.keys" "$work/base.keys" > "$work/new.keys"
if [ ! -s "$work/new.keys" ]; then
  echo "shellcheck-new: no new findings ($(wc -l < "$work/head.txt" | tr -d ' ') at HEAD, $(wc -l < "$work/base.txt" | tr -d ' ') at $base)"
  exit 0
fi
echo "shellcheck-new: findings HEAD adds over $base (count, then the finding):"
uniq -c "$work/new.keys"
LC_ALL=C sort -u "$work/new.keys" | LC_ALL=C comm -23 - <(LC_ALL=C sort -u "$work/base.keys") > "$work/fresh.keys"
if [ -s "$work/fresh.keys" ]; then
  echo "where the kinds $base has none of are:"
  while IFS= read -r line; do
    key="$(printf '%s\n' "$line" | keys)"
    if grep -qxF -- "$key" "$work/fresh.keys"; then printf '%s\n' "$line"; fi
  done < "$work/head.txt"
fi
exit 1
