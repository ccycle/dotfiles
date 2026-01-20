#!/usr/bin/env bash
set -e

echo ""
echo "=== Build Dry-Run ==="
HOSTNAME=$(scutil --get LocalHostName)
echo "Building for hostname: $HOSTNAME (dry-run)..."

# Assuming flakes are used.
git add .
nix build "./bootstrap#darwinConfigurations.bootstrap.aarch64-darwin.system" --impure -L --dry-run
nix build ".#darwinConfigurations.private.aarch64-darwin.system" --impure -L --dry-run

echo "✅ Build dry-run passed."
echo ""
echo "🎉 All checks passed! You are safe to commit."
