{
  inputs = {
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    attic.url = "github:zhaofengli/attic";
    devx.url = "github:input-output-hk/devx";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    ghc-wasm-meta.url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
    ghcup.flake = false;
    ghcup.url = "github:haskell/ghcup-hs";
    ghq-migrator.flake = false;
    ghq-migrator.url = "github:astj/ghq-migrator";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.05";
    nixpkgs-2211.url = "github:nixos/nixpkgs/22.11";
    nixpkgs-2305.url = "github:nixos/nixpkgs/23.05";
    nixpkgs-2311.url = "github:nixos/nixpkgs/23.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/24.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/24.11";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    pip2nix.url = "github:nix-community/pip2nix";
    sops-nix.url = "github:Mic92/sops-nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.url = "github:pyproject-nix/uv2nix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages.init-dotfiles = pkgs.callPackage ./init-dotfiles.nix { };
      };
      flake = {
        pkgs = inputs.nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ] (system:
          inputs.nixpkgs.legacyPackages.${system}
        );
        modules = inputs.nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ] (system: [
          ./modules.nix
          ./home.nix
        ]);
        homeManagerModules.default = { ... }: {
          imports = [
            ./home.nix
            ./modules.nix
          ];
        };
        darwinModules.base = ./darwin-base.nix;
        darwinConfigurations."private" = inputs.nix-darwin.lib.darwinSystem {
          modules = [
            ./darwin.nix
          ];
          specialArgs = inputs // { inherit inputs; };
        };
        extraSpecialArgs = inputs.nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ] (system:
          let
            mkPkgs = input: input.legacyPackages.${system};
            env = if builtins.pathExists ./generated/env.nix then import ./generated/env.nix else import ./env-impure.nix;
          in
          inputs // {
            inherit (inputs) self;
            pkgs-2211 = mkPkgs inputs.nixpkgs-2211;
            pkgs-2305 = mkPkgs inputs.nixpkgs-2305;
            pkgs-2311 = mkPkgs inputs.nixpkgs-2311;
            pkgs-2405 = mkPkgs inputs.nixpkgs-2405;
            pkgs-2411 = mkPkgs inputs.nixpkgs-2411;
            pkgs-2505 = mkPkgs inputs.nixpkgs-2505;
            pkgs-unstable = mkPkgs inputs.nixpkgs-unstable;
          } // env
        );
        homeConfigurations =
          let
            env = if builtins.pathExists ./generated/env.nix then import ./generated/env.nix else import ./env-impure.nix;
            system = "aarch64-darwin";
          in
          {
            "${env.username}" = inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              modules = [
                ./home.nix
                ./modules.nix
              ];
              extraSpecialArgs = inputs.self.extraSpecialArgs.${system};
            };
          };
      };
    };
}
