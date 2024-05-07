{ pkgs, ... }:
let gmake = pkgs.callPackage ./gmake { }; in
{
  home.packages = [ gmake ];
}
