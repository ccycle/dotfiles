{ config, lib, pkgs, inputs, ... }:
let
  # brew-nix default desktoppr has a broken installPhase; override so $out/bin/desktoppr exists.
  desktoppr = pkgs.brewCasks.desktoppr.overrideAttrs (_: {
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp ./usr/local/bin/desktoppr $out/bin/
      runHook postInstall
    '';
  });
in
{
  imports = [ inputs.stylix.darwinModules.stylix ];
  stylix.enable = true;
  stylix.image = ./wp4725691-mac-os-x-earth-horizon-wallpapers.jpg;

  # desktoppr must run in the user's GUI login session; activationScripts run as root
  # and don't have access to the WindowServer, so use a LaunchAgent that runs at login.
  # Plist is installed under the primary user's HOME: ~/Library/LaunchAgents/org.nixos.set-wallpaper.plist
  # (not under /Library/LaunchAgents/). If missing after rebuild, check:
  #   ls /run/current-system/user/Library/LaunchAgents/
  #   ls -la "$HOME/Library/LaunchAgents/"
  # and ensure ~/Library/LaunchAgents exists; then log out and log in again.
  launchd.user.agents.set-wallpaper = lib.mkIf config.stylix.enable {
    serviceConfig.RunAtLoad = true;
    serviceConfig.StandardOutPath = "/tmp/set-wallpaper.log";
    serviceConfig.StandardErrorPath = "/tmp/set-wallpaper.log";
    script = ''
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) set-wallpaper starting"
      sleep 3
      "${desktoppr}/bin/desktoppr" "${config.stylix.image}" && echo "desktoppr ok" || echo "desktoppr failed: $?"
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) set-wallpaper done"
    '';
  };
}
