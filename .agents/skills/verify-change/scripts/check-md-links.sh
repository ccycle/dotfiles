#!/usr/bin/env bash
# Enforce how markdown prose refers to files in this repository:
#
#   A. A reference that resolves to a tracked file must be a relative markdown
#      link, not inline code. Inline code is opaque to editors, review UIs and
#      link checkers, so a renamed file silently rots the reference.
#   B. Every relative link target must exist, resolved from the linking file's
#      own directory (that is what a reader's editor resolves it against).
#
# Only path-shaped references (they contain "/") are checked by rule A. A bare
# file name like `home.nix` names a file to create or a file in the same
# directory just as often as it names one specific file, so demanding a link
# would invent wrong targets.
#
# Fenced code blocks are exempt: commands and snippets there are examples, not
# references. Anchor fragments are not validated - only the file they point at.
# References that resolve to nothing are left alone: rewriting them would just
# produce a link that rule B rejects.
#
# Scope defaults to the prose-heavy markdown agents write. Pass --all to check
# every tracked *.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "${REPO_ROOT}"

export PATH_SPAN_RE='`[A-Za-z0-9_.@+/-]*/[A-Za-z0-9_.@+/-]+\.(md|nix|sh|py|ts|tsx|ya?ml|json|toml)`'
export LINK_RE='\]\([^)]+\)'
# One awk pass extracts every candidate from every file: spawning grep per line
# took ~50s. Inline-code and link syntax only occurs in prose; a fenced block
# toggles off everything between its opening and closing fence. Matches are
# split on whitespace, mirroring the word splitting of the former
# `for x in $(grep -o ...)` loop. Output: file TAB line TAB rule TAB piece.
# The regexes come in through ENVIRON because awk -v would eat backslashes.
EXTRACT_AWK='
  function emit(rule, re,    s, n, i, parts) {
    s = $0
    while (match(s, re)) {
      n = split(substr(s, RSTART, RLENGTH), parts, /[ \t]+/)
      for (i = 1; i <= n; i++) if (parts[i] != "") print FILENAME "\t" FNR "\t" rule "\t" parts[i]
      s = substr(s, RSTART + RLENGTH)
    }
  }
  FNR == 1 { fence = 0 }
  /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
  !fence { emit("A", ENVIRON["PATH_SPAN_RE"]); emit("B", ENVIRON["LINK_RE"]) }
'

files=()
if [ "${1:-}" = "--all" ]; then
  while IFS= read -r f; do files+=("$f"); done < <(git ls-files '*.md')
else
  while IFS= read -r f; do files+=("$f"); done < <(
    git ls-files '*.md' | grep -E '(^docs/|(^|/)design\.md$|^\.agents/skills/)' || true
  )
fi

# Path of $2 (relative to the repo root) as seen from directory $1 (relative to
# the repo root, "." for the root itself). POSIX relative, no leading "./".
relpath() {
  local -a from to out
  local i j
  [ "$1" = "." ] && {
    printf '%s' "$2"
    return
  }
  IFS=/ read -ra from <<<"$1"
  IFS=/ read -ra to <<<"$2"
  i=0
  while [ "$i" -lt "${#from[@]}" ] && [ "$i" -lt "${#to[@]}" ] && [ "${from[$i]}" = "${to[$i]}" ]; do
    i=$((i + 1))
  done
  out=()
  for ((j = i; j < ${#from[@]}; j++)); do out+=(".."); done
  for ((j = i; j < ${#to[@]}; j++)); do out+=("${to[$j]}"); done
  local IFS=/
  printf '%s' "${out[*]}"
}

# Resolve a reference written in $1 (the markdown file) to a link target that
# is valid relative to that file. Directory-relative wins over repo-root-
# relative: that is also how a reader would interpret the plain path.
resolve() {
  local file=$1 ref=$2 dir
  dir=$(dirname "$file")
  [ "$ref" = "$file" ] && return 1
  case "$ref" in .local/* | /*) return 1 ;; esac
  if [ -e "$dir/$ref" ]; then
    printf '%s' "$ref"
    return 0
  fi
  if [ -e "$ref" ]; then
    relpath "$dir" "$ref"
    return 0
  fi
  return 1
}

set -f # spans are split on whitespace; never glob-expand them
violations=0
report() {
  printf '  %s\n' "$1"
  violations=$((violations + 1))
}

existing=()
for file in "${files[@]}"; do
  [ -f "$file" ] && existing+=("$file")
done

while IFS=$'\t' read -r file line rule piece; do
  if [ "$rule" = A ]; then
    ref="${piece//\`/}"
    if target=$(resolve "$file" "$ref"); then
      report "$file:$line: inline code reference - use [$ref]($target)"
    fi
    continue
  fi

  target="${piece#*](}"
  target="${target%)}"
  case "$target" in \#* | '') continue ;; esac
  case "$target" in
  *://* | //* | mailto:* | tel:* | data:*) continue ;;
  esac
  target="${target#<}"
  target="${target%>}"
  target="${target%%#*}"
  target="${target//%20/ }"
  case "$target" in '') continue ;; esac
  if [ ! -e "$(dirname "$file")/$target" ] && [ ! -e "$target" ]; then
    report "$file:$line: broken link - $target does not exist"
  fi
done < <([ "${#existing[@]}" -eq 0 ] || awk "$EXTRACT_AWK" "${existing[@]}")

if [ "$violations" -gt 0 ]; then
  echo "Markdown link check failed: ${violations} violation(s)." >&2
  exit 1
fi
echo "Markdown link check passed (${#files[@]} file(s))."
