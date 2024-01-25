{ pkgs, ghcup, ... }:
# let ghcupPackage = pkgs.callPackage ./ghcup { inherit ghcup; }; in
{
  # home.packages = [ ghcupPackage ];
  programs.zsh.initExtra = ''
    [ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"
  '';
}
