{ pkgs, ... }:

let
  cursor-agent = pkgs.callPackage ./cursor-agent/drv.nix { };
in
{
  home.packages = pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") [
    cursor-agent
  ];

  home.sessionVariables = {
    EDITOR = "cursor --wait";
  };

  programs.zsh = {
    shellAliases = {
      # Cursor loses keychain access after sleep; manual unlock restores auth.
      # https://github.com/cursor/cursor/issues/3490#issuecomment-3733405558
      security-unlock-keychain = "security unlock-keychain ~/Library/Keychains/login.keychain-db";
    };
  };
}
