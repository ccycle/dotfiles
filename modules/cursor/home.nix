{ pkgs, ... }:

let
  cursor-agent = pkgs.callPackage ./package.nix { };
in
{
  home.packages = pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") [
    cursor-agent
  ];

  home.sessionVariables = {
    EDITOR = "cursor --wait";
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      # Skip switching to zsh when Cursor Agent is running
      if [[ -n "$CURSOR_AGENT" ]]; then
        :
      else
        exec zsh
      fi
    '';
    };
}
