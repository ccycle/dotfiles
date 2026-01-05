{ pkgs, ... }:

{
  home.packages = [ pkgs.just ];
  programs.zsh.initContent = ''
    source <(${pkgs.just}/bin/just --completions zsh)
  '';
}
