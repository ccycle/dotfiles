#!/usr/bin/env bash
set -e

# --- Configuration & Helpers ---
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
echo "Detected system: $SYSTEM"

function check_syntax() {
  echo "=== 🔍 Checking Nix Syntax ==="
  find . -name "*.nix" -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 | xargs -0 nix-instantiate --parse >/dev/null
  echo "✅ Syntax check passed."
}

function check_structure() {
  echo "=== 📦 Checking Package by Feature structure ==="
  local report
  report=$(nix eval --json --impure \
    --expr 'import ./.agents/skills/verify-change/scripts/package-by-feature/check.nix { repoRoot = ./.; }')
  if [ "$(echo "$report" | jq -r '.ok')" != "true" ]; then
    echo "$report" | jq -r '.violations[] | "❌ [\(.rule)] \(.file): \(.message)"'
    echo "Structure check failed ($(echo "$report" | jq -r '.count') violation(s))."
    echo "Rules are declared in .agents/skills/verify-change/scripts/package-by-feature/rules.nix."
    return 1
  fi
  echo "✅ Structure check passed."
}

function check_md_links() {
  echo "=== 🔗 Checking markdown file references ==="
  "${REPO_ROOT}/.agents/skills/verify-change/scripts/check-md-links.sh"
  echo ""
}

# comin evaluates the committed flake purely, so anything injected with
# --override-input (e.g. gitignored .local/* flakes) silently diverges from
# what comin deploys. All per-host values must be committed in
# modules/<host>/darwin.nix instead. See modules/comin/design.md.
function check_no_override_input() {
  echo "=== 🚫 Checking for --override-input usage ==="
  local hits
  hits="$(git -C "${REPO_ROOT}" grep --untracked -nE -- '--override-input|"path:' -- ':!*.md' ':!flake.lock' ':!.agents/skills/verify-change/scripts/check.sh' || true)"
  if [ -n "${hits}" ]; then
    echo "${hits}"
    echo "❌ --override-input / path: flake inputs are forbidden; commit the value in modules/<host>/darwin.nix." >&2
    return 1
  fi
  echo "✅ No --override-input usage."
  echo ""
}

function check_recipients() {
  echo "=== 🔐 Checking sops recipient drift against age key ledger ==="
  "${REPO_ROOT}/.agents/skills/credentials-manager/scripts/check-recipients.sh"
  echo ""
}

function check_claude_hooks() {
  echo "=== 🪝 Testing Claude Code hooks ==="
  "${REPO_ROOT}/modules/claude/hooks/block-secret-screen-reads.test.sh"
  echo ""
}

# Verify every module's declared expected-bins.txt binaries actually exist in
# a profile's built closure. Package attribute names don't always match their
# binary name (e.g. `ripgrep` -> `rg`), so this checks concrete binary names
# rather than trying to derive them from home.packages/environment.systemPackages.
# home-manager packages (home.packages) and nix-darwin packages
# (environment.systemPackages) land in different output paths -
# config.home-manager.users.<user>.home.path/bin and <system>/sw/bin
# respectively - confirmed empirically; both are checked.
# home.path is part of the system closure, so both are found from the already
# built system output; a separate `nix build` per user would re-evaluate the
# whole config (~12s each).
function check_expected_bins() {
  local flake_path=$1
  local config=$2
  local system_out=$3

  # Scope manifest discovery to this flake's own module tree: bootstrap has
  # a disjoint module tree (bootstrap/modules/) that never imports root
  # modules/, so checking root manifests against a bootstrap build (or vice
  # versa) would report false failures for modules that were never in scope.
  local modules_root
  if [ "$flake_path" = "." ]; then
    modules_root="${REPO_ROOT}/modules"
  else
    modules_root="${REPO_ROOT}/${flake_path#./}/modules"
  fi

  local manifests
  manifests=$(find "${modules_root}" -name "expected-bins.txt" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | sort)
  if [ -z "$manifests" ]; then
    return 0
  fi

  echo "  --- 🔧 Checking expected binaries ---"
  local bin_dirs=("${system_out}/sw/bin")
  local hm_out
  for hm_out in $(nix path-info -r "$system_out" | grep -- '-home-manager-path$'); do
    bin_dirs+=("${hm_out}/bin")
  done

  local failed=0
  while IFS= read -r manifest; do
    [ -z "$manifest" ] && continue
    while IFS= read -r bin; do
      bin="${bin%%#*}"
      bin="$(echo "$bin" | xargs)"
      [ -z "$bin" ] && continue
      local found=0
      for dir in "${bin_dirs[@]}"; do
        if [ -e "${dir}/${bin}" ]; then
          found=1
          break
        fi
      done
      if [ "$found" -eq 0 ]; then
        echo "  ❌ missing expected binary '${bin}' (${manifest#"${REPO_ROOT}/"})"
        failed=1
      fi
    done <"$manifest"
  done <<<"$manifests"

  if [ "$failed" -eq 0 ]; then
    echo "  ✅ Expected binaries present."
  fi
  return $failed
}

# Flatten darwinConfigurations into fully-qualified config paths. Entries are
# either direct darwinSystem results (mac-mini-m4) or per-architecture attrsets
# (private.<arch>); resolving both here lets every downstream step use the
# uniform path <flake>#darwinConfigurations.<config>.<attr>.
function list_configs() {
  nix eval "${1}#darwinConfigurations" --apply '
    configs:
    let isConfig = v: v ? system;
        resolve = name:
          let v = configs.${name};
          in if isConfig v then [ name ]
             else map (sub: "${name}.${sub}")
               (builtins.filter (sub: isConfig v.${sub}) (builtins.attrNames v));
    in builtins.concatStringsSep " " (builtins.concatMap resolve (builtins.attrNames configs))
  ' --raw --impure
}

function build_dry_run() {
  local flake_path=$1
  local config=$2
  local profile="${config%%.*}"

  echo "=== 🏗️ Build: ${profile} (${flake_path}) ==="

  # Skip configs built for another architecture.
  local config_system
  config_system="$(nix eval "${flake_path}#darwinConfigurations.${config}.pkgs.system" --raw --impure 2>/dev/null || echo "$SYSTEM")"
  if [ "$config_system" != "$SYSTEM" ]; then
    echo "Skipping ${profile} (incompatible system: $config_system)"
    return 0
  fi

  local target="${flake_path}#darwinConfigurations.${config}.system"
  echo "Target: $target"
  # A real build instead of --dry-run: check_expected_bins needs the output,
  # and one build costs about the same as a dry-run plus a second evaluation.
  local system_out
  system_out=$(nix build "$target" --impure -L --no-link --print-out-paths)
  echo "✅ $profile build passed."

  check_expected_bins "$flake_path" "$config" "$system_out"
}

# --- Main Execution ---

# 0. Ensure Nix SSL cert exists (required to reach binary caches)
if [ -f /etc/nix/nix.conf ] && grep -q 'ssl-cert-file' /etc/nix/nix.conf; then
  CERT_FILE=$(grep 'ssl-cert-file' /etc/nix/nix.conf | awk '{print $3}')
  if [ -n "$CERT_FILE" ] && [ ! -f "$CERT_FILE" ]; then
    echo "=== 🔐 Regenerating missing Nix SSL cert: $CERT_FILE ==="
    security export -t certs -f pemseq \
      -k /System/Library/Keychains/SystemRootCertificates.keychain \
      -o /tmp/nix-certs-root.pem
    security export -t certs -f pemseq \
      -k /Library/Keychains/System.keychain \
      -o /tmp/nix-certs-system.pem 2>/dev/null || cp /dev/null /tmp/nix-certs-system.pem
    cat /tmp/nix-certs-root.pem /tmp/nix-certs-system.pem | sudo tee "$CERT_FILE" >/dev/null
    rm -f /tmp/nix-certs-root.pem /tmp/nix-certs-system.pem
    echo "✅ SSL cert regenerated."
  fi
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# 1. Syntax check
check_syntax
echo ""

# 2. Package by Feature structure check
check_structure
echo ""

# 2.5. Markdown file references (links, not inline code; no broken targets)
check_md_links

# 2.55. comin-incompatible override inputs
check_no_override_input

# 2.6. Sops recipient check against the age key ledger
check_recipients

check_claude_hooks

# 3. Build every compatible profile (or only the one given as $1)
PROFILE="${1:-}"
echo "=== 📋 Discovering profiles in root flake ==="
ROOT_CONFIGS=$(list_configs ".")
echo "Found: $ROOT_CONFIGS"
matched=0
for config in $ROOT_CONFIGS; do
  if [ -n "$PROFILE" ] && [ "${config%%.*}" != "$PROFILE" ]; then
    continue
  fi
  matched=1
  build_dry_run "." "$config"
  echo ""
done
if [ "$matched" -eq 0 ]; then
  echo "❌ Unknown profile '${PROFILE}'. Available: ${ROOT_CONFIGS}"
  exit 1
fi

echo "🎉 All checks passed! You are safe to commit."
