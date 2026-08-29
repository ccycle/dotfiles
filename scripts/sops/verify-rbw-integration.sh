#!/usr/bin/env bash
# Verify rbw + sops integration works.
set -euo pipefail

ITEM="${RBW_ITEM_NAME:-dotfiles-age-key-$(hostname -s)}"

# Check rbw is installed
command -v rbw >/dev/null 2>&1 || { echo "FAIL: rbw not found"; exit 1; }

# Check sops is installed
command -v sops >/dev/null 2>&1 || { echo "FAIL: sops not found"; exit 1; }

# Check wrapper script exists and is executable
SCRIPT="$(dirname "$0")/sops-with-rbw"
[[ -x "$SCRIPT" ]] || { echo "FAIL: wrapper script not executable: $SCRIPT"; exit 1; }

# Check if rbw is unlocked
if rbw unlocked >/dev/null 2>&1; then
    # Check rbw can fetch the age key
    rbw get "$ITEM" >/dev/null 2>&1 || { echo "FAIL: rbw item '$ITEM' not found"; exit 1; }
    echo "OK: rbw + sops integration verified (rbw unlocked, key accessible)"
else
    echo "WARN: rbw is locked - skipping key fetch test"
    echo "OK: rbw + sops integration structure verified (unlock rbw to test fully)"
fi
