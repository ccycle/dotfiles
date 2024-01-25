{ pkgs, ... }:
{
  home.packages = [ (pkgs.callPackage ./age { }) ];
}
