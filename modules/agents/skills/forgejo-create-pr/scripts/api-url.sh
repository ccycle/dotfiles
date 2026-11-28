#!/usr/bin/env bash
set -euo pipefail

[ $# -eq 1 ] || {
  echo "usage: api-url.sh <remote>" >&2
  exit 2
}
remote_url="$(git config --get "remote.$1.url")"
[[ $remote_url =~ ^(https://[^/]+)/([^/]+)/([^/]+)$ ]] || {
  echo "error: remote $1 URL is not https://<host>/<owner>/<repo>: $remote_url" >&2
  exit 2
}
echo "${BASH_REMATCH[1]}/api/v1/repos/${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
