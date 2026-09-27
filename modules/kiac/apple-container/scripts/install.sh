#!/usr/bin/env bash
# Installs apple/container to /usr/local via Apple's real signed installer.
#
# Deliberately NOT wired into nix-darwin's system.activationScripts: this
# runs `sudo installer -pkg` against a real system location, and doing
# that unattended on every `darwin-rebuild switch` was judged too risky
# to automate. Run this by hand instead, passing the flake-pinned .pkg
# store path (flake.nix's `apple-container-pkg` input).
#
# Why the real installer and not a Nix-store extraction: apple/container's
# apiserver hardcodes its plugin-discovery root to /usr/local (matching
# the .pkg's own install-location). Neither the documented
# CONTAINER_INSTALL_ROOT env var nor the config.toml install-root
# override worked against a Nix store relocation in 1.4.1 — the apiserver
# kept failing with "cannot find any plugins with type network". The real
# installer, to its real official location, is the only path that's
# actually been shown to work.
set -euo pipefail

PKG_PATH="${1:?usage: install.sh <path-to-container-installer.pkg> [target-version]}"
TARGET_VERSION="${2:-1.4.1}"

installed_version=$(pkgutil --pkg-info com.apple.container-installer 2>/dev/null | awk -F': ' '/^version:/{print $2}') || true

if [ "$installed_version" = "$TARGET_VERSION" ]; then
  echo "apple/container $TARGET_VERSION already installed."
  exit 0
fi

echo "installing apple/container $TARGET_VERSION (currently: ${installed_version:-none})..."

# `installer` validates the .pkg by extension/UTI, not just content — a
# Nix store path (no .pkg suffix) is rejected outright ("the package path
# specified was invalid"), so stage a same-content copy under a .pkg name.
staged_dir=$(mktemp -d)
trap 'rm -rf "$staged_dir"' EXIT
staged_pkg="$staged_dir/container-installer.pkg"
cp "$PKG_PATH" "$staged_pkg"

sudo installer -pkg "$staged_pkg" -target /
