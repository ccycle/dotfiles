#!/bin/sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
target_dir="${repo_root}/.local/storage"
target_file="${target_dir}/flake.nix"

show_usage() {
  echo "Usage: $(basename -- "$0") <service>=<path> [<service>=<path> ...]"
  echo ""
  echo "Sets custom.storage.volumes.<service> entries in .local/storage/flake.nix."
  echo "Existing entries for services not listed are preserved."
  echo ""
  echo "Examples:"
  echo "  $(basename -- "$0") forgejo=/Volumes/WD_BLACK immich=/Volumes/WD_BLACK"
  echo "  $(basename -- "$0") llm-server=~/Library/Caches/llama.cpp"
}

if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_usage >&2
  exit 1
fi

entries_file="$(mktemp)"
trap 'rm -f "${entries_file}" "${entries_file}.tmp"' EXIT

if [ -f "${target_file}" ]; then
  grep -E '^ +[A-Za-z0-9_-]+ = "' "${target_file}" |
    sed -E 's/^ +([A-Za-z0-9_-]+) = "(.*)";/\1 \2/' >"${entries_file}"
fi

for arg in "$@"; do
  service="${arg%%=*}"
  path="${arg#*=}"
  if [ "${service}" = "${arg}" ] || [ -z "${path}" ]; then
    echo "Invalid argument: ${arg} (expected <service>=<path>)" >&2
    exit 1
  fi
  grep -v "^${service} " "${entries_file}" >"${entries_file}.tmp" || true
  mv "${entries_file}.tmp" "${entries_file}"
  echo "${service} ${path}" >>"${entries_file}"
done

mkdir -p "${target_dir}"
{
  echo "{"
  echo "  outputs = { ... }: {"
  echo "    darwinModules.default = { ... }: {"
  echo "      custom.storage.volumes = {"
  sort "${entries_file}" | while read -r service path; do
    echo "        ${service} = \"${path}\";"
  done
  echo "      };"
  echo "    };"
  echo "  };"
  echo "}"
} >"${target_file}"

echo "Updated ${target_file}:"
sort "${entries_file}" | while read -r service path; do
  echo "  custom.storage.volumes.${service} = \"${path}\""
done
