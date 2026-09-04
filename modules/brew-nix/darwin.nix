{ pkgs, inputs, ... }:
{
  brew-nix.enable = true;
  imports = [ inputs.brew-nix.darwinModules.default ];

  environment.systemPackages = [
    (pkgs.brewCasks.desktoppr.overrideAttrs (o: {
      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp ./usr/local/bin/desktoppr $out/bin/
        runHook postInstall
      '';
    }))
    pkgs.brewCasks.appcleaner
    pkgs.brewCasks.betterdisplay
    pkgs.brewCasks.zotero
  ];
}
