{ pkgs, ... }:

{
  home.packages = with pkgs; [
    graphviz
    imagemagick
    inkscape
  ];
}
