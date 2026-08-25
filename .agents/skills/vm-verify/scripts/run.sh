#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../../../.." && pwd)"
BASE_IMAGE="ghcr.io/cirruslabs/macos-sequoia-base:latest" # bump to a newer Cirrus base image tag as needed
VM_NAME="dotfiles-verify-$(basename "$repo_root")"
VM_USER="admin"
VM_PASS="admin" # default credentials on Cirrus Labs' base image
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o PreferredAuthentications=password -o PubkeyAuthentication=no)
REMOTE_DIR="dotfiles"
FAILED=0
FRESH=0

for arg in "$@"; do
  case "$arg" in
  --fresh) FRESH=1 ;;
  *)
    echo "Unknown option: $arg" >&2
    echo "Usage: $0 [--fresh]" >&2
    exit 1
    ;;
  esac
done

pass() { echo "✅ $1"; }
fail() {
  echo "❌ $1"
  FAILED=1
}

ssh_vm() {
  sshpass -p "$VM_PASS" ssh "${SSH_OPTS[@]}" "${VM_USER}@${vm_ip}" -- "$@"
}

# --- Preflight ---
echo "=== 🔍 Preflight checks ==="

if [ "$(uname -m)" != "arm64" ]; then
  echo "vm-verify requires an Apple Silicon (arm64) host to run macOS guest VMs via Tart." >&2
  exit 1
fi

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found. It's declared in modules/tart/darwin.nix; run:" >&2
  echo "  scripts/darwin-rebuild.sh private" >&2
  exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "sshpass not found. It's declared in modules/tart/darwin.nix; run:" >&2
  echo "  scripts/darwin-rebuild.sh private" >&2
  exit 1
fi

pass "tart, sshpass, and arm64 host confirmed"

# --- VM lifecycle ---
# The VM is kept (stopped, not deleted) between runs so it can be reused: its
# $HOME is VM-local and unrelated worktree-to-worktree, so there's no
# correctness reason to throw it away every time, and reuse skips the Nix
# install + full package closure fetch on every run after the first. Pass
# --fresh to force a clean reclone (base image bump, suspected corruption).
cleanup() {
  echo "=== 🧹 Stopping ${VM_NAME} (kept for reuse; pass --fresh to reclone) ==="
  tart stop "$VM_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [ "$FRESH" -eq 1 ] || ! tart get "$VM_NAME" >/dev/null 2>&1; then
  echo "=== 🖥️  Cloning ${BASE_IMAGE} as ${VM_NAME} ==="
  tart delete "$VM_NAME" >/dev/null 2>&1 || true # in case a stale/corrupt clone exists
  tart clone "$BASE_IMAGE" "$VM_NAME"
else
  echo "=== ♻️  Reusing existing VM ${VM_NAME} ==="
fi

echo "=== ▶️  Booting ${VM_NAME} ==="
tart run "$VM_NAME" --no-graphics &

echo "=== ⏳ Waiting for VM IP ==="
vm_ip=""
for _ in $(seq 1 60); do
  vm_ip="$(tart ip "$VM_NAME" 2>/dev/null || true)"
  [ -n "$vm_ip" ] && break
  sleep 2
done
if [ -z "$vm_ip" ]; then
  echo "Timed out waiting for ${VM_NAME} to get an IP address." >&2
  exit 1
fi
pass "VM IP: ${vm_ip}"

echo "=== ⏳ Waiting for SSH ==="
ssh_ready=0
for _ in $(seq 1 60); do
  if ssh_vm true 2>/dev/null; then
    ssh_ready=1
    break
  fi
  sleep 2
done
if [ "$ssh_ready" -ne 1 ]; then
  echo "Timed out waiting for SSH on ${VM_NAME} (${vm_ip})." >&2
  exit 1
fi
pass "SSH reachable"

# --- Transfer worktree into the VM ---
echo "=== 📦 Transferring worktree into VM ==="
sshpass -p "$VM_PASS" rsync -az --delete --exclude=.git -e "ssh ${SSH_OPTS[*]}" "${repo_root}/" "${VM_USER}@${vm_ip}:${REMOTE_DIR}/"
pass "Worktree transferred to ~/${REMOTE_DIR} in VM"

# --- Install Nix and run darwin-rebuild switch inside the VM ---
echo "=== 🔧 Installing Nix and running darwin-rebuild switch (private) in VM ==="
if ssh_vm bash -s <<REMOTE; then
set -euo pipefail
# Plain nix-darwin (nix.package = pkgs.nix, nix.enable defaults to true) expects to
# manage the Nix install itself; the Determinate Nix installer's daemon conflicts
# with that and nix-darwin refuses to activate ("Determinate detected, aborting
# activation"), so use the upstream multi-user installer instead.
command -v nix >/dev/null 2>&1 || sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes
set +u # /etc/profile (via /etc/bashrc) references \$PS1, unset in a non-interactive shell
. /etc/profile
set -u
cd ~/${REMOTE_DIR}
scripts/darwin-rebuild.sh private
REMOTE
  pass "darwin-rebuild switch (private) succeeded in VM"
else
  fail "darwin-rebuild switch (private) failed in VM"
fi

# --- Verify mkOutOfStoreSymlink targets resolve into the VM-local checkout ---
echo "=== 🔗 Verifying dotfiles symlinks ==="
if [ "$FAILED" -eq 0 ]; then
  symlink_report="$(
    ssh_vm bash -s <<'REMOTE'
set -uo pipefail
FAILED=0
check_symlink() {
  local home_path="$1"
  local expected_rel="$2"
  local expected="$HOME/dotfiles/${expected_rel}"
  local actual
  actual="$(readlink -f "$home_path" 2>/dev/null || true)"
  if [ "$actual" = "$expected" ]; then
    echo "PASS ${home_path} -> ${actual}"
  else
    echo "FAIL ${home_path} -> ${actual:-<missing>} (expected ${expected})"
    FAILED=1
  fi
}

check_symlink "$HOME/.claude/skills" "modules/agents/skills"
check_symlink "$HOME/.claude/settings.json" "modules/claude/settings.json"
check_symlink "$HOME/.claude/hooks" "modules/claude/hooks"
check_symlink "$HOME/.claude/CLAUDE.md" "modules/agents/rules/rules.md"
check_symlink "$HOME/.claude/rules/loop-engineering.md" "modules/agents/rules/loop-engineering.md"
check_symlink "$HOME/.cursor/rules/global-behavioral-rules.mdc" "modules/agents/rules/rules.md"
check_symlink "$HOME/.config/herdr/config.toml" "modules/herdr/config.toml"
check_symlink "$HOME/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" "modules/herdr/reviewr-config.toml"
check_symlink "$HOME/.config/direnv/direnvrc" "modules/direnv/direnvrc"

exit "$FAILED"
REMOTE
  )" || FAILED=1
  echo "$symlink_report" | while IFS= read -r line; do
    case "$line" in
    PASS\ *) echo "✅ ${line#PASS }" ;;
    FAIL\ *) echo "❌ ${line#FAIL }" ;;
    esac
  done
else
  echo "Skipping symlink verification because darwin-rebuild switch failed."
fi

# --- Summary ---
echo "=== 📋 Summary ==="
if [ "$FAILED" -eq 0 ]; then
  pass "vm-verify passed for profile 'private' (worktree: ${repo_root})"
  exit 0
else
  echo "❌ vm-verify failed for profile 'private' (worktree: ${repo_root})"
  exit 1
fi
