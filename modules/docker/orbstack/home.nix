{ pkgs, ... }:
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
}
