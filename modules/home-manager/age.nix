{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # age
    (callPackage ./age { })
  ];
}
