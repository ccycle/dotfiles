{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    serena.url = "github:oraios/serena";
    serena.flake = false;
  };
  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
      in
      {
        flake.flakeModule = importApply ./flake-module.nix {
          inherit flake-parts-lib;
          inherit (inputs) serena;
        };
      }
    );
}
