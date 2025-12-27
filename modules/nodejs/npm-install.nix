{ pkgs, ... }:
let npmDeps = import ./npm-install { inherit pkgs; nodejs = pkgs.nodejs; }; in
{
  home.packages = [ npmDeps.nodeDependencies ];
}
