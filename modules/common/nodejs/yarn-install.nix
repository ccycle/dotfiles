{ pkgs, ... }:
let
  # https://discourse.nixos.org/t/filtering-source-trees-with-nix-and-nixpkgs/19148
  srcRoot = ./yarn-install;
  filter = name: type:
    ! ((type == "directory") && ((baseNameOf name) == "node_modules"));
  src = pkgs.lib.cleanSourceWith { inherit filter; src = srcRoot; };

  node-modules = pkgs.mkYarnPackage {
    inherit src;
  };
  yarn-install = pkgs.stdenv.mkDerivation {
    pname = node-modules.package.name;
    version = node-modules.package.version;
    inherit src;
    installPhase = ''
      mkdir -p $out/bin
      cp -s -L ${node-modules}/libexec/${node-modules.package.name}/node_modules/${node-modules.package.name}/node_modules/.bin/* $out/bin
    '';
  };
in
{
  home.packages = [ yarn-install ];
  programs.git.ignores = [ "node_modules/" ];
}
