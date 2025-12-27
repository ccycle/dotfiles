{ config, pkgs, lib, ... }:

{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    # Use system SSH on macOS to enable Keychain integration
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    extraConfig = lib.mkIf pkgs.stdenv.isDarwin ''
      UseKeychain yes
    '';
  };
}
