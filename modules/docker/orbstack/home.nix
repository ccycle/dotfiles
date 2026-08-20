{ pkgs, lib, ... }:
let
  orbstack = pkgs.brewCasks.orbstack.overrideAttrs (old: {
    # brew-nix's installPhase does not call runHook postInstall, so we append directly.
    # We also remove *:com.apple.* fork files (provenance, macl, quarantine, etc.)
    # from the bundle, which otherwise break codesign verification
    # (Gatekeeper reports "damaged and can't be opened").
    installPhase = old.installPhase + ''
      find "$out/Applications/OrbStack.app" -name '*:com.apple.*' -delete
      for cmd in orb orbctl; do
        ln -s "$out/Applications/OrbStack.app/Contents/MacOS/bin/$cmd" "$out/bin/$cmd"
      done
    '';
  });
in
{
  home.packages = [ orbstack ];

  home.activation.orbstack-start-at-login = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${orbstack}/bin/orb" ]; then
      "${orbstack}/bin/orb" config set app.start_at_login true 2>/dev/null &
      _orb_pid=$!
      sleep 5
      if kill -0 "$_orb_pid" 2>/dev/null; then
        kill "$_orb_pid" 2>/dev/null || true
        echo "Warning: orb config set hung (OrbStack daemon not responding); start_at_login not set this run."
      fi
      wait "$_orb_pid" 2>/dev/null || true
    fi
  '';

  home.activation.orbstack-docker-context = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v docker &>/dev/null; then
      docker context use orbstack 2>/dev/null || echo "Warning: Failed to set Docker context to orbstack"
    fi
  '';

  # Enable OrbStack's native Kubernetes (K3s) cluster declaratively. The
  # config key is `k8s.enable` (verified via `orb config list`), NOT
  # `k8s.enabled` as some third-party docs/terraform providers claim.
  # Enabling the cluster lets a throwaway k8s testbed (see the
  # e2e-test-k8s-immich skill) run on-demand via `orb start k8s` /
  # `orb stop k8s` without manual settings.
  home.activation.orbstack-k8s-enable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${orbstack}/bin/orb" ]; then
      "${orbstack}/bin/orb" config set k8s.enable true 2>/dev/null &
      _orb_k8s_pid=$!
      sleep 5
      if kill -0 "$_orb_k8s_pid" 2>/dev/null; then
        kill "$_orb_k8s_pid" 2>/dev/null || true
        echo "Warning: orb config set hung (OrbStack daemon not responding); k8s.enable not set this run."
      fi
      wait "$_orb_k8s_pid" 2>/dev/null || true
    fi
  '';
}
