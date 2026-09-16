#!/bin/bash
# Install the Antigravity CLI (agy) via the official installer.
# Official docs: https://antigravity.google/docs/cli/install/
#
# Usage: agy-install
#
# The official installer is idempotent: if ~/.local/bin/agy already exists, it
# exits without reinstalling (agy automatically self-updates in the background
# on every run).
# To force a fresh reinstall: rm ~/.local/bin/agy && agy-install
set -euo pipefail

curl -fsSL https://antigravity.google/cli/install.sh | bash
