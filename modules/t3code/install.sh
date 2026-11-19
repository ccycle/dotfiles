#!/bin/bash
# Install the T3 Code CLI (t3) via the official installer.
# Official docs: https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md
#
# Usage: t3-install
#
# The installer fetches the latest stable GitHub Release, verifies it against
# SHA256SUMS, and writes the ~/.local/bin/t3 launcher. Re-running it is safe;
# after the first install, update with `t3 update` instead.
set -euo pipefail

curl -fsSL https://t3.codes/install.sh | sh
