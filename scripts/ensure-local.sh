#!/bin/sh
# Ensure the machine-local .local state exists for the current checkout.
#
# Worktrees never carry the gitignored .local/ directory, which breaks builds
# that depend on it (e.g. the storage volumeRoot assertion). This script
# restores it from the repo's main checkout:
#   - storage / obsidian-vault: pure machine state, copied verbatim
#   - dotfiles: path-dependent, (re)generated to point at the CURRENT checkout
#     so that builds validate this checkout's own files instead of main's
#   - user: identity of whoever is running this script right now, (re)generated
#     every run - `id -un`/$HOME rather than $USER, since $USER is unset for
#     launchd-spawned processes (confirmed live: Forgejo Actions' runner daemon
#     has no $USER, which crashed a build with an empty users.users."" before
#     this existed). Callers that need the real invoking user under sudo
#     (darwin-rebuild.sh) run this script before sudo, not after.
#   - hints point at setup-* scripts when the main checkout also lacks a
#     module (e.g. on a fresh machine)
#
# Only ever writes inside the current checkout, never the main one.

set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

check_mode=false
case "${1:-}" in
--check)
  check_mode=true
  ;;
-h | --help)
  cat <<'EOF'
Usage: ensure-local.sh [--check]

Ensures the machine-local .local state for the current checkout.

  --check   Report what would be created/rewritten without changing anything;
            exits 1 if changes are needed.
EOF
  exit 0
  ;;
esac

changes_needed=0

need_change() {
  changes_needed=1
}

# Print in the mode-appropriate wording; the side effect itself runs outside.
act() {
  if [ "$check_mode" = true ]; then
    printf '[ensure-local][check] %s\n' "$2"
    need_change
  else
    printf 'ensure-local: %s\n' "$1"
  fi
}

info() {
  printf 'ensure-local: %s\n' "$1"
}

warn() {
  printf 'ensure-local: %s\n' "$1" >&2
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  warn "not inside a git work tree; nothing to do."
  exit 0
}

main_root="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
main_root="${main_root:-}"

# --- storage / obsidian-vault: machine state, copied from the main checkout ---
for m in storage obsidian-vault; do
  target="${repo_root}/.local/${m}"
  [ -d "${target}" ] && continue

  src="${main_root}/.local/${m}"
  if [ -n "${main_root}" ] && [ -d "${src}" ]; then
    act "copied .local/${m}/ from ${main_root}" "would copy .local/${m}/ from ${main_root}"
    if [ "$check_mode" = false ]; then
      mkdir -p "${repo_root}/.local"
      cp -R "${src}" "${target}"
    fi
  else
    case "$m" in
    storage) warn "missing .local/storage/ everywhere. Run: scripts/setup-local-storage.sh <service>=/Volumes/<YOUR_DRIVE>" ;;
    obsidian-vault) warn "missing .local/obsidian-vault/ everywhere. Run: scripts/setup-obsidian-vault.sh /path/to/your/vault" ;;
    esac
    need_change
  fi
done

# --- dotfiles: path-dependent, synced to the current checkout root ---
dotfiles_local="${repo_root}/.local/dotfiles"
if [ -f "${dotfiles_local}/flake.nix" ] && grep -q "${repo_root}" "${dotfiles_local}/flake.nix"; then
  info "dotfiles.dir already points at ${repo_root}"
else
  act "wrote .local/dotfiles/flake.nix (custom.dotfiles.dir = ${repo_root})" \
    "would write .local/dotfiles/flake.nix (custom.dotfiles.dir = ${repo_root})"
  if [ "$check_mode" = false ]; then
    mkdir -p "${dotfiles_local}"
    cat >"${dotfiles_local}/flake.nix" <<-EOF
		{
		  outputs = { ... }: {
		    darwinModules.default = { ... }: {
		      custom.dotfiles.dir = "${repo_root}";
		    };
		  };
		}
	EOF
  fi
fi

# --- user: identity of whoever is running this script, refreshed every run ---
user_local="${repo_root}/.local/user"
current_username="$(id -un)"
current_home="${HOME:-}"
if [ -f "${user_local}/flake.nix" ] &&
  grep -q "username = \"${current_username}\";" "${user_local}/flake.nix" 2>/dev/null &&
  grep -q "homeDirectory = \"${current_home}\";" "${user_local}/flake.nix" 2>/dev/null; then
  info "user identity already up to date (${current_username})"
else
  act "wrote .local/user/flake.nix (username = ${current_username})" \
    "would write .local/user/flake.nix (username = ${current_username})"
  if [ "$check_mode" = false ]; then
    mkdir -p "${user_local}"
    cat >"${user_local}/flake.nix" <<-EOF
		{
		  outputs = { ... }: {
		    username = "${current_username}";
		    homeDirectory = "${current_home}";
		  };
		}
	EOF
  fi
fi

if [ "$check_mode" = true ]; then
  [ "$changes_needed" -eq 0 ] || exit 1
fi
