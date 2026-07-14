{ pkgs, pkgs-2211, ... }:

{
  home.packages = with pkgs; [
    bundix
    nil
    nix-index
    nix-info
    nix-prefetch-git
    nix-tree
    nix-update
  ] ++ (with pkgs-2211; [
    nix-du
    xdot
  ]);
}
