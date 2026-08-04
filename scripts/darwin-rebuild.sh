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

storage_local="${repo_root}/.local/storage"
if [ -d "${storage_local}" ]; then
  overrides="${overrides} --override-input storage-config \"path:${storage_local}\""
else
  echo "Note: .local/storage/ not found. Services requiring external storage will fail." >&2
  echo "  Run: scripts/setup-local-storage.sh <service>=/Volumes/<YOUR_DRIVE>" >&2
  echo "" >&2
fi

obsidian_local="${repo_root}/.local/obsidian-vault"
if [ -d "${obsidian_local}" ]; then
  overrides="${overrides} --override-input obsidian-vault-config \"path:${obsidian_local}\""
else
  echo "Note: .local/obsidian-vault/ not found. Obsidian vault config will use defaults." >&2
  echo "  Run: scripts/setup-obsidian-vault.sh /path/to/your/vault" >&2
  echo "" >&2
fi

dotfiles_local="${repo_root}/.local/dotfiles"
if [ -d "${dotfiles_local}" ]; then
  overrides="${overrides} --override-input dotfiles-config \"path:${dotfiles_local}\""
else
  # Auto-create with the current repo root path so DOTFILES_DIR env var is never needed.
  mkdir -p "${dotfiles_local}"
  cat > "${dotfiles_local}/flake.nix" <<- LOCALEOF
		{
		  outputs = { ... }: {
		    darwinModules.default = { ... }: {
		      custom.dotfiles.dir = "${repo_root}";
		    };
		  };
		}
	LOCALEOF
  overrides="${overrides} --override-input dotfiles-config \"path:${dotfiles_local}\""
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
    attic push dotfiles "${p}" >/dev/null 2>&1 \
      || echo "Warning: attic push failed for ${p}; cache not updated." >&2
  done
fi
