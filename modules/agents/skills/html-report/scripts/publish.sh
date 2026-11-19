#!/usr/bin/env bash
# Publish one self-contained HTML report and print where to read it.
# STATIC_REPORTS_DIR/URL (static-reports host) wins and prints a URL;
# otherwise HTML_REPORTS_DIR (local dir) is used and the absolute path is printed.
# Usage: publish.sh <file.html> [<project-slug>]
set -euo pipefail

src="${1:?usage: publish.sh <file.html> [<project-slug>]}"
[[ -f $src ]] || {
  echo "no such file: $src" >&2
  exit 1
}

if [[ -n ${STATIC_REPORTS_DIR:-} ]]; then
  : "${STATIC_REPORTS_URL:?STATIC_REPORTS_DIR is set but STATIC_REPORTS_URL is not}"
  [[ -d $STATIC_REPORTS_DIR ]] || {
    echo "missing dir: $STATIC_REPORTS_DIR" >&2
    exit 1
  }
  root="$STATIC_REPORTS_DIR/agent-reports" base="$STATIC_REPORTS_URL/agent-reports"
elif [[ -n ${HTML_REPORTS_DIR:-} ]]; then
  root="$HTML_REPORTS_DIR" base="$HTML_REPORTS_DIR"
else
  echo "neither STATIC_REPORTS_DIR nor HTML_REPORTS_DIR is set (shell predates darwin-rebuild?)" >&2
  exit 1
fi

# Default slug is the repo name; the common dir (not --show-toplevel) keeps
# worktrees from being filed under their worktree directory name.
# Outside a repo the caller must pass one.
common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
slug="${2:-$([[ -n $common_dir ]] && basename "$(dirname "$common_dir")")}"
[[ -n $slug && $slug != "." ]] || {
  echo "pass a project slug (not inside a git repo)" >&2
  exit 1
}

# Timestamp prefix makes file_server's name-sorted listing chronological.
rel="$slug/$(date +%Y%m%d-%H%M%S)-$(basename "$src")"
mkdir -p "$root/$slug"
cp "$src" "$root/$rel"
echo "$base/$rel"
