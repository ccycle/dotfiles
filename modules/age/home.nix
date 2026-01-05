{ pkgs, self, ... }:
{
  home.packages = with pkgs; [
    # age
    (callPackage ./default.nix { inherit self; })
  ];
}
