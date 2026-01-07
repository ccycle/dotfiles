{
  # Main system configuration flake.
  #
  # NOTE: If this is a fresh installation and you have private flake inputs,
  # you MUST run the bootstrap flake first to provision access tokens.
  #
  # See `bootstrap/flake.nix` for details.
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
    nixpkgs-2511.url = "github:NixOS/nixpkgs/25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    gemini-cli.url = "github:google-gemini/gemini-cli";
    gemini-cli.flake = false;
    pip2nix.url = "github:nix-community/pip2nix";
    sops-nix.url = "github:Mic92/sops-nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.url = "github:pyproject-nix/uv2nix";
  };

  outputs = inputs@{ flake-parts, nix-darwin, ... }:
    let
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      linuxSystems = [ "aarch64-linux" "x86_64-linux" ];
      allSystems = darwinSystems ++ linuxSystems;

      forAllSystems = inputs.nixpkgs.lib.genAttrs allSystems;
      forDarwinSystems = inputs.nixpkgs.lib.genAttrs darwinSystems;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = allSystems;
      flake = {
        pkgs = forAllSystems (system:
          inputs.nixpkgs.legacyPackages.${system}
        );
        modules = forAllSystems (system: [
          ./home.nix
        ]);
        homeManagerModules.default = { ... }: {
          imports = [
            ./home.nix
            inputs.sops-nix.homeManagerModules.sops
          ];
        };
        darwinModules.base = { ... }: {
          imports = [
            ./darwin.nix
          ];
        };
        darwinConfigurations = {
          private = forDarwinSystems (system:
            let
              env = if builtins.pathExists ./generated/env.nix then import ./generated/env.nix else import ./env-impure.nix;
            in
            inputs.nix-darwin.lib.darwinSystem {
              modules = [
                ./bootstrap/module.nix
                ./darwin.nix
              ];
              specialArgs = inputs // { inherit inputs system; } // env;
            }
          );
        };

        apps = forDarwinSystems (system: {
          darwin-rebuild = {
            type = "app";
            program = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
          };
        });

        extraSpecialArgs = forAllSystems (system:
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
        homeConfigurations = {
          private = forAllSystems (system:
            inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              modules = [
                ./home.nix
                inputs.sops-nix.homeManagerModules.sops
              ];
              extraSpecialArgs = inputs.self.extraSpecialArgs.${system};
            }
          );
        };
      };
    };
}
