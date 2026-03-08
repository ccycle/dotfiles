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
      "${orbstack}/bin/orb" config set app.start_at_login true 2>/dev/null || echo "Warning: OrbStack is not running. Run 'orb config set app.start_at_login true' after starting OrbStack."
    fi
  '';
}
