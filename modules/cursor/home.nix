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

    # Cursor's GUI editor can't open over SSH, so fall back to vi whenever
    # the shell is an SSH session (same $SSH_TTY/$SSH_CONNECTION check as
    # modules/pinentry/home.nix).
    initContent = ''
      if [ -n "''${SSH_TTY:-}''${SSH_CONNECTION:-}" ]; then
        export EDITOR=vi
      fi
    '';
  };
}
