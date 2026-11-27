#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../../../.." && pwd)"
worktree="$(basename "$repo_root")"
BASE_IMAGE="ghcr.io/cirruslabs/macos-sequoia-base:latest"
GOLDEN="dotfiles-verify-golden"
GOLDEN_DISK_GB=100
GOLDEN_MIN_FREE_GB=40
CLONE="dotfiles-verify-${worktree}--run$$"
VM_USER="admin"
BASE_IMAGE_PASSWORD="admin"
VM_HOME="/Users/${VM_USER}"
VM_AGE_KEY="${VM_HOME}/.config/sops/age/keys.txt"
REMOTE_DIR="dotfiles"
PROFILE="macbook-air-m1"
HOST_STATE_DIR="${HOME}/.tart/vm-verify"
MAX_RUNNING_MACOS_GUESTS=2
SSH_BASE_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR)
FAILED=0
REBUILD_GOLDEN=0

for arg in "$@"; do
  case "$arg" in
  --rebuild-golden) REBUILD_GOLDEN=1 ;;
  *)
    echo "Unknown option: $arg" >&2
    echo "Usage: $0 [--rebuild-golden]" >&2
    exit 1
    ;;
  esac
done

pass() { echo "✅ $1"; }
fail() {
  echo "❌ $1"
  FAILED=1
}

held_locks=()
try_lock() {
  if mkdir "$1" 2>/dev/null; then
    echo $$ >"$1/pid"
    held_locks+=("$1")
    return 0
  fi
  local pid lock_is_fully_written
  pid="$(cat "$1/pid" 2>/dev/null || true)"
  lock_is_fully_written="$pid"
  if [ -n "$lock_is_fully_written" ] && ! kill -0 "$pid" 2>/dev/null; then
    rm -rf "$1"
  fi
  return 1
}
lock_wait() {
  until try_lock "$1"; do
    echo "⏳ waiting for ${2} (held by PID $(cat "$1/pid" 2>/dev/null || echo '?'))"
    sleep 10
  done
}
acquire_slot() {
  while :; do
    for s in $(seq 1 "$MAX_RUNNING_MACOS_GUESTS"); do
      try_lock "${HOST_STATE_DIR}/slot${s}" && return 0
    done
    echo "⏳ all ${MAX_RUNNING_MACOS_GUESTS} VM slots busy; retrying in 10s"
    sleep 10
  done
}

running_vms=()
vm_ip=""
boot_vm() {
  tart run "$1" --no-graphics >/dev/null 2>&1 &
  running_vms+=("$1")
  vm_ip=""
  for _ in $(seq 1 60); do
    vm_ip="$(tart ip "$1" 2>/dev/null || true)"
    [ -n "$vm_ip" ] && break
    sleep 2
  done
  [ -n "$vm_ip" ] || {
    echo "Timed out waiting for $1 to get an IP address." >&2
    exit 1
  }
  for _ in $(seq 1 60); do
    ssh_vm true 2>/dev/null && return 0
    sleep 2
  done
  echo "Timed out waiting for SSH on $1 (${vm_ip})." >&2
  exit 1
}
ssh_vm() {
  ssh "${SSH_BASE_OPTS[@]}" -i "${HOST_STATE_DIR}/id_ed25519" -o PreferredAuthentications=publickey "${VM_USER}@${vm_ip}" -- "$@"
}
stop_vm() {
  tart stop "$1" >/dev/null 2>&1 || true
}

tmp=""
cleanup() {
  set +e
  for vm in "${running_vms[@]+"${running_vms[@]}"}"; do stop_vm "$vm"; done
  tart delete "$CLONE" >/dev/null 2>&1
  for l in "${held_locks[@]+"${held_locks[@]}"}"; do rm -rf "$l"; done
  [ -n "$tmp" ] && rm -rf "$tmp"
}
trap cleanup EXIT

echo "=== 🔍 Preflight checks ==="
if [ "$(uname -m)" != "arm64" ]; then
  echo "vm-verify requires an Apple Silicon (arm64) host to run macOS guest VMs via Tart." >&2
  exit 1
fi
for bin in tart sshpass sops age-keygen; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "${bin} not found. tart/sshpass are declared in modules/tart/darwin.nix, sops/age in the sops module; run:" >&2
    echo "  .agents/skills/darwin-rebuild/scripts/darwin-rebuild.sh ${PROFILE}" >&2
    exit 1
  fi
done
cleanup_script="${repo_root}/.agents/skills/cleanup-worktrees/scripts/cleanup-worktree.sh"
if ! grep -qF -- '(--run[0-9]+)?' "$cleanup_script"; then
  echo "${cleanup_script} no longer matches run clones named like ${CLONE}; update its VM teardown pattern or CLONE in $0." >&2
  exit 1
fi
mkdir -p "$HOST_STATE_DIR"
[ -f "${HOST_STATE_DIR}/id_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -C vm-verify -f "${HOST_STATE_DIR}/id_ed25519"
tmp="$(mktemp -d)"
pass "tools, arm64 host, and VM SSH key confirmed"

echo "=== 🏗️  Building ${PROFILE} for the VM on the host ==="
cat >"${tmp}/vm.nix" <<EOF
(builtins.getFlake "${repo_root}").darwinConfigurations."${PROFILE}".extendModules {
  specialArgs = { username = "${VM_USER}"; homeDirectory = "${VM_HOME}"; };
  modules = [ ./vm-module.nix ];
}
EOF
write_vm_module() {
  cat >"${tmp}/vm-module.nix" <<EOF
{ lib, ... }: {
  custom.dotfiles.dir = "${VM_HOME}/${REMOTE_DIR}";
  services.comin.enable = lib.mkForce false;
  $1
}
EOF
}

write_vm_module ""
inventory="$(nix eval --impure --json --file "${tmp}/vm.nix" config --apply '
  c: let pick = s: { inherit (s) key format path; }; in {
    keyFiles = [ c.sops.age.keyFile c.home-manager.users.'"${VM_USER}"'.sops.age.keyFile ];
    sys = builtins.mapAttrs (_: pick) c.sops.secrets;
    hm = builtins.mapAttrs (_: pick) c.home-manager.users.'"${VM_USER}"'.sops.secrets;
  }')"
if ! jq -e --arg key "$VM_AGE_KEY" '.keyFiles | all(. == $key)' <<<"$inventory" >/dev/null; then
  echo "sops.age.keyFile is $(jq -c .keyFiles <<<"$inventory"), expected ${VM_AGE_KEY}; update VM_AGE_KEY in $0." >&2
  exit 1
fi
if jq -e '[.sys[], .hm[]] | any(.format != "yaml" or (.key | contains("/")))' <<<"$inventory" >/dev/null; then
  echo "A secret is not a flat yaml key; extend the dummy-secret generator in $0." >&2
  exit 1
fi

age-keygen -o "${tmp}/age.key" 2>/dev/null
pub="$(age-keygen -y "${tmp}/age.key")"
jq -r '[.sys[], .hm[]] | map(.key) | unique[] | "\(.): vm-verify-dummy-\(.)"' <<<"$inventory" >"${tmp}/plain.yaml"
(cd "$tmp" && sops --encrypt --age "$pub" --input-type yaml --output-type yaml plain.yaml >vm-secrets.yaml)
sys_overrides="$(jq -r '.sys | keys[] | "sops.secrets.\"\(.)\".sopsFile = lib.mkForce ./vm-secrets.yaml;"' <<<"$inventory")"
hm_overrides="$(jq -r '.hm | keys[] | "sops.secrets.\"\(.)\".sopsFile = lib.mkForce ./vm-secrets.yaml;"' <<<"$inventory")"
write_vm_module "${sys_overrides}
  home-manager.sharedModules = [ { ${hm_overrides} } ];"

system_out="$(nix build --impure --file "${tmp}/vm.nix" system -L --out-link "${tmp}/closure-gc-root" --print-out-paths)"
pass "built ${system_out}"

copy_closure() {
  NIX_SSHOPTS="${SSH_BASE_OPTS[*]} -i ${HOST_STATE_DIR}/id_ed25519" \
    nix copy --no-check-sigs --to "ssh-ng://${VM_USER}@${vm_ip}?remote-program=sudo%20/nix/var/nix/profiles/default/bin/nix-daemon" "$system_out"
}

echo "=== 🎟️  Acquiring one of ${MAX_RUNNING_MACOS_GUESTS} VM slots ==="
acquire_slot
pass "holding ${held_locks[-1]}"

if [ "$REBUILD_GOLDEN" -eq 1 ] || ! tart get "$GOLDEN" >/dev/null 2>&1; then
  lock_wait "${HOST_STATE_DIR}/golden.lock" "another run building ${GOLDEN}"
  if [ "$REBUILD_GOLDEN" -eq 1 ] || ! tart get "$GOLDEN" >/dev/null 2>&1; then
    echo "=== 🥇 Building ${GOLDEN} from ${BASE_IMAGE} ==="
    building="${GOLDEN}-building"
    tart delete "$building" >/dev/null 2>&1 || true
    tart clone "$BASE_IMAGE" "$building"
    tart set "$building" --disk-size "$GOLDEN_DISK_GB"
    boot_vm_pw() {
      tart run "$building" --no-graphics >/dev/null 2>&1 &
      running_vms+=("$building")
      for _ in $(seq 1 60); do
        vm_ip="$(tart ip "$building" 2>/dev/null || true)"
        [ -n "$vm_ip" ] && sshpass -p "$BASE_IMAGE_PASSWORD" ssh "${SSH_BASE_OPTS[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no "${VM_USER}@${vm_ip}" true 2>/dev/null && return 0
        sleep 2
      done
      echo "Timed out waiting for SSH on ${building}." >&2
      exit 1
    }
    boot_vm_pw
    sshpass -p "$BASE_IMAGE_PASSWORD" ssh "${SSH_BASE_OPTS[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no "${VM_USER}@${vm_ip}" \
      'mkdir -p -m 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' <"${HOST_STATE_DIR}/id_ed25519.pub"
    ssh_vm 'yes | sudo diskutil repairDisk disk0 >/dev/null; sudo diskutil apfs resizeContainer disk0s2 0 >/dev/null 2>&1; true'
    free_gb="$(ssh_vm "df -g / | awk 'NR==2 {print \$4}'")"
    if [ "$free_gb" -lt "$GOLDEN_MIN_FREE_GB" ]; then
      echo "Only ${free_gb} GB free in ${building} after resizing, need ${GOLDEN_MIN_FREE_GB}; raise GOLDEN_DISK_GB in $0." >&2
      exit 1
    fi
    ssh_vm 'sh <(curl -fsSL https://nixos.org/nix/install) --daemon --yes' >/dev/null
    ssh_vm 'sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin && sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin'
    copy_closure
    stop_vm "$building"
    tart delete "$GOLDEN" >/dev/null 2>&1 || true
    tart rename "$building" "$GOLDEN"
    pass "${GOLDEN} built and seeded"
  fi
fi

echo "=== 🖥️  Cloning ${GOLDEN} as ${CLONE} ==="
tart clone "$GOLDEN" "$CLONE"
boot_vm "$CLONE"
pass "VM ${CLONE} up at ${vm_ip}"

echo "=== 📦 Transferring worktree, test age key, and closure ==="
rsync -az --delete --exclude=.git --exclude=.local -e "ssh ${SSH_BASE_OPTS[*]} -i ${HOST_STATE_DIR}/id_ed25519" "${repo_root}/" "${VM_USER}@${vm_ip}:${REMOTE_DIR}/"
ssh_vm "mkdir -p -m 700 '${VM_AGE_KEY%/*}' && umask 077 && cat > '${VM_AGE_KEY}'" <"${tmp}/age.key"
copy_closure
pass "worktree, key, and closure in VM"

echo "=== 🔧 Activating ${system_out} in VM ==="
if ssh_vm "sudo -H /nix/var/nix/profiles/default/bin/nix-env -p /nix/var/nix/profiles/system --set '${system_out}' && sudo -H '${system_out}/activate'"; then
  pass "switch (${PROFILE}) succeeded in VM"
else
  fail "switch (${PROFILE}) failed in VM"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "=== 🔗 Verifying dotfiles symlinks and secrets ==="
  secret_checks="$(jq -r '[.sys, .hm][] | to_entries[] | "\(.value.path) vm-verify-dummy-\(.value.key)"' <<<"$inventory")"
  report="$(
    ssh_vm bash -s <<REMOTE
set -uo pipefail
FAILED=0
check_symlink() {
  local expected="\$HOME/${REMOTE_DIR}/\$2" actual
  actual="\$(readlink -f "\$1" 2>/dev/null || true)"
  if [ "\$actual" = "\$expected" ]; then echo "PASS \$1 -> \$actual"
  else echo "FAIL \$1 -> \${actual:-<missing>} (expected \$expected)"; FAILED=1; fi
}
check_symlink "\$HOME/.claude/skills/ask-me-to-do" "modules/agents/skills/ask-me-to-do"
check_symlink "\$HOME/.claude/settings.json" "modules/claude/settings.json"
check_symlink "\$HOME/.claude/hooks" "modules/claude/hooks"
check_symlink "\$HOME/.claude/CLAUDE.md" "modules/agents/rules/rules.md"
check_symlink "\$HOME/.claude/rules/loop-engineering.md" "modules/agents/rules/loop-engineering.md"
check_symlink "\$HOME/.cursor/rules/global-behavioral-rules.mdc" "modules/agents/rules/rules.md"
check_symlink "\$HOME/.config/herdr/config.toml" "modules/herdr/config.toml"
check_symlink "\$HOME/.config/herdr/plugins/config/persiyanov.reviewr/config.toml" "modules/herdr/reviewr-config.toml"
check_symlink "\$HOME/.config/direnv/direnvrc" "modules/direnv/direnvrc"
wait_for_async_decryption() {
  actual=""
  for _ in \$(seq 1 30); do
    actual="\$(sudo cat "\$1" 2>/dev/null || true)"
    [ -n "\$actual" ] && break
    sleep 2
  done
}
while read -r path expected; do
  [ -n "\$path" ] || continue
  wait_for_async_decryption "\$path" </dev/null
  if [ "\$actual" = "\$expected" ]; then echo "PASS secret \$path"
  else echo "FAIL secret \$path (got '\${actual:-<missing>}', expected '\$expected')"; FAILED=1; fi
done <<'CHECKS'
${secret_checks}
CHECKS
exit "\$FAILED"
REMOTE
  )" || FAILED=1
  while IFS= read -r line; do
    case "$line" in
    PASS\ *) echo "✅ ${line#PASS }" ;;
    FAIL\ *) echo "❌ ${line#FAIL }" ;;
    esac
  done <<<"$report"
else
  echo "Skipping symlink/secret verification because the switch failed."
fi

echo "=== 📋 Summary ==="
if [ "$FAILED" -eq 0 ]; then
  pass "vm-verify passed for profile '${PROFILE}' (worktree: ${repo_root})"
else
  echo "❌ vm-verify failed for profile '${PROFILE}' (worktree: ${repo_root})"
  exit 1
fi
