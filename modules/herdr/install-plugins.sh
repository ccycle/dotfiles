#!/usr/bin/env bash
set -euo pipefail

plugins=(
  "persiyanov.reviewr persiyanov/herdr-reviewr"
  "herdr-file-viewer smarzban/herdr-file-viewer"
)

missing=()
for tool in herdr git curl jq; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "herdr-install-plugins: missing required command(s): ${missing[*]}" >&2
  exit 1
fi

installed_ids=$(herdr plugin list --json | jq -r '.result.plugins[].plugin_id')

for entry in "${plugins[@]}"; do
  read -r id repo <<<"$entry"
  if grep -qxF "$id" <<<"$installed_ids"; then
    echo "==> updating $id"
    herdr plugin update "$id" -y
  else
    echo "==> installing $id from $repo"
    herdr plugin install "$repo" -y
  fi
done

installed_ids=$(herdr plugin list --json | jq -r '.result.plugins[].plugin_id')
for entry in "${plugins[@]}"; do
  read -r id _ <<<"$entry"
  if ! grep -qxF "$id" <<<"$installed_ids"; then
    echo "herdr-install-plugins: $id is still not listed by 'herdr plugin list' after install" >&2
    exit 1
  fi
done
echo "herdr-install-plugins: all plugins installed"
