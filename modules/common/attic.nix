{ attic, system, ... }:
{
  home.packages = [ attic.packages.${system}.default ];
}
