#!/bin/sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
target_dir="${repo_root}/.local/storage"
target_file="${target_dir}/flake.nix"

show_usage() {
  echo "Usage: $(basename -- "$0") <volume-root>"
  echo ""
  echo "Creates .local/storage/flake.nix with the given volume root path."
  echo ""
  echo "Examples:"
  echo "  $(basename -- "$0") /Volumes/WD_BLACK"
  echo "  $(basename -- "$0") /Volumes/KIOXIA"
}

if [ $# -ne 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_usage >&2
  exit 1
fi

volume_root="$1"

if [ -f "${target_file}" ]; then
  current=$(grep 'volumeRoot' "${target_file}" | sed 's/.*"\(.*\)".*/\1/')
  echo "Existing config: volumeRoot = \"${current}\""
  printf "Overwrite with \"%s\"? [y/N] " "${volume_root}"
  read -r answer
  case "${answer}" in
    [yY]*) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

mkdir -p "${target_dir}"
cat > "${target_file}" << EOF
{
  outputs = { ... }: {
    darwinModules.default = { ... }: {
      custom.storage.volumeRoot = "${volume_root}";
    };
  };
}
EOF

echo "Created ${target_file}"
echo "  custom.storage.volumeRoot = \"${volume_root}\""
