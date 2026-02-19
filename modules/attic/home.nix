{ inputs, system, ... }:
{
  home.packages = [ inputs.attic.packages.${system}.default ];
}
