{ pkgs, ... }:

{
  home.packages = with pkgs; [
    emacs
    emacsPackages.magit
  ];
}
