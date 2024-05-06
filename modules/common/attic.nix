{ attic, pkgs, ... }:
let attic-package = pkgs.callPackage "${attic}/package.nix" { }; in {
  home.packages = [ attic-package ];
}
