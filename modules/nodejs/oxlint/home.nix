{ pkgs, ... }:
{
  home.packages = with pkgs; [ oxlint ];
}
