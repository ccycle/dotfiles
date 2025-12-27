{
  description = "npm-install package with node2nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        node2nix-codegen = import ./node2nix-codegen { inherit pkgs; };
      };
    };
}
