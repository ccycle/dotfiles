{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
