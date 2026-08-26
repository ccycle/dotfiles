#!/bin/sh
set -eu

NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
arch="$(${NIX} eval --impure --raw --expr 'builtins.currentSystem')"

# Discover available profiles from the main flake's darwinConfigurations.
# Enumerates fully-qualified config paths (e.g. "private.aarch64-darwin",
# "mac-mini-m4") by checking whether each top-level attr is a direct
# darwinSystem (has .system) or a per-architecture attrset.
all_configs="$(${NIX} eval "${repo_root}#darwinConfigurations" --apply '
  configs:
  let
    isConfig = v: v ? system;
    resolve = name:
      let v = configs.${name};
      in if isConfig v then [ name ]
         else map (sub: "${name}.${sub}")
           (builtins.filter (sub: isConfig v.${sub}) (builtins.attrNames v));
  in builtins.concatStringsSep "\n"
    (builtins.concatMap resolve (builtins.attrNames configs))
' --raw 2>/dev/null || echo "")"

# User-facing short names (strip architecture suffix for display)
display_profiles="$(echo "${all_configs}" | sed 's/\.\(aarch64-darwin\|x86_64-darwin\)$//' | sort -u)"

show_usage() {
  echo "Usage: $(basename -- "$0") <profile>"
  echo ""
  echo "Profiles:"
  echo "  bootstrap        Run bootstrap flake (provisions sops-nix secrets on fresh install)"
  if [ -n "${display_profiles}" ]; then
    echo "${display_profiles}" | while IFS= read -r p; do
      printf "  %-18s Run main flake configuration\n" "${p}"
    done
  fi
}

if [ $# -ne 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_usage >&2
  exit 1
fi

profile="$1"

if [ "${profile}" = "bootstrap" ]; then
  flake_root="${repo_root}/bootstrap"
  app="default"
  config="bootstrap.${arch}"
else
  flake_root="${repo_root}"
  app="darwin-rebuild"

  if echo "${all_configs}" | grep -qx "${profile}"; then
    config="${profile}"
  elif echo "${all_configs}" | grep -qx "${profile}\.${arch}"; then
    config="${profile}.${arch}"
  else
    echo "Unknown profile: ${profile}" >&2
    echo "" >&2
    show_usage >&2
    exit 1
  fi
fi

overrides=""

# Ensure machine-local .local state for this checkout (restores
# storage/obsidian-vault from the main checkout and syncs dotfiles.dir to this
# checkout), then wire the overrides for whatever now exists.
"${repo_root}/scripts/ensure-local.sh"

for m in storage obsidian-vault; do
  if [ -d "${repo_root}/.local/${m}" ]; then
    overrides="${overrides} --override-input ${m}-config \"path:${repo_root}/.local/${m}\""
  fi
done

if [ -d "${repo_root}/.local/dotfiles" ]; then
  overrides="${overrides} --override-input dotfiles-config \"path:${repo_root}/.local/dotfiles\""
fi

if [ -d "${repo_root}/.local/user" ]; then
  overrides="${overrides} --override-input user-config \"path:${repo_root}/.local/user\""
fi

eval sudo -H ${NIX} run "${flake_root}#${app}" -- switch --flake "${flake_root}#${config}" --impure -L ${overrides}

# Best-effort push of the new system and home-manager closures to the attic
# cache (push-on-event model). Failures must not fail the rebuild.
if [ "${app}" != "default" ] && command -v attic >/dev/null 2>&1; then
  system_path="$(readlink -f /run/current-system 2>/dev/null || true)"
  hm_path="$(readlink -f "${HOME}/.local/state/nix/profiles/home-manager" 2>/dev/null || true)"
  for p in ${system_path} ${hm_path}; do
    [ -n "${p}" ] || continue
    echo "Pushing ${p} to attic cache 'dotfiles'..."
    if ! attic push dotfiles "${p}" >/dev/null 2>&1; then
      echo "Warning: attic push failed for ${p}; cache not updated." >&2
      echo "Hint: If this is a new machine, ensure you have run 'attic login' and installed the Caddy CA." >&2
    fi
  done
fi
