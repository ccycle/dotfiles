#!/bin/sh
# Generate .local/user/flake.nix for the bootstrap flake, using `id -un`
# rather than $USER/$SUDO_USER: unlike a real interactive bootstrap run,
# a CI dry-run (launchd-spawned, no $USER) has no env var to read, but
# `id -un` still resolves via the OS UID. Self-contained to bootstrap/ on
# purpose - see bootstrap/flake.nix's header comment on avoiding shared
# abstractions with the root flake.
#
# Not needed for a real interactive bootstrap run (documented usage:
# `nix run ./bootstrap -- switch --flake ./bootstrap`) - user-default's
# own $USER/$SUDO_USER fallback already covers that case.

set -eu

bootstrap_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
user_local="${bootstrap_root}/.local/user"

current_username="$(id -un)"
current_home="${HOME:-}"
# nix-darwin hardcodes users.users.root.home to null-or-/var/root - see
# scripts/ensure-local.sh at the repo root for the same substitution and
# the reasoning behind it.
if [ "${current_username}" = "root" ]; then
  current_username="ci"
fi

mkdir -p "${user_local}"
cat >"${user_local}/flake.nix" <<-EOF
	{
	  outputs = { ... }: {
	    username = "${current_username}";
	    homeDirectory = "${current_home}";
	  };
	}
EOF

echo "ensure-user: wrote ${user_local}/flake.nix (username = ${current_username})"
