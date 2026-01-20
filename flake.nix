{
  # Main system configuration flake.
  #
  # NOTE: If this is a fresh installation and you have private flake inputs,
  # you MUST run the bootstrap flake first to provision access tokens.
  #
  # See `bootstrap/flake.nix` for details.
  inputs = {
    attic.url = "github:zhaofengli/attic";
    brew-nix.url = "github:BatteredBunny/brew-nix";
    devx.url = "github:input-output-hk/devx";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    ghc-wasm-meta.url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
    ghcup.flake = false;
    ghcup.url = "github:haskell/ghcup-hs";
    ghq-migrator.flake = false;
    ghq-migrator.url = "github:astj/ghq-migrator";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    gwq.url = "github:d-kuro/gwq";
    gwq.flake = false;
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
    ghostty.url = "github:ghostty-org/ghostty";
    pip2nix.url = "github:nix-community/pip2nix";
    serena.url = "github:oraios/serena";
    sops-nix.url = "github:Mic92/sops-nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    yazi-plugins.flake = false;
    yazi-plugins.url = "github:yazi-rs/plugins";
  };

  outputs = inputs@{ flake-parts, nix-darwin, ... }:
    let
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      linuxSystems = [ "aarch64-linux" "x86_64-linux" ];
      allSystems = darwinSystems ++ linuxSystems;

      forAllSystems = inputs.nixpkgs.lib.genAttrs allSystems;
      forDarwinSystems = inputs.nixpkgs.lib.genAttrs darwinSystems;

      mkSpecialArgs = system:
        let
          mkPkgs = input: input.legacyPackages.${system};
          env = if builtins.pathExists ./generated/env.nix then import ./generated/env.nix else import ./env-impure.nix;
        in
        inputs // {
          inherit inputs;
          inherit (inputs) self;
          inherit system;
          pkgs-2211 = mkPkgs inputs.nixpkgs-2211;
          pkgs-2305 = mkPkgs inputs.nixpkgs-2305;
          pkgs-2311 = mkPkgs inputs.nixpkgs-2311;
          pkgs-2405 = mkPkgs inputs.nixpkgs-2405;
          pkgs-2411 = mkPkgs inputs.nixpkgs-2411;
          pkgs-2505 = mkPkgs inputs.nixpkgs-2505;
          pkgs-2511 = mkPkgs inputs.nixpkgs-2511;
          pkgs-unstable = mkPkgs inputs.nixpkgs-unstable;
        } // env;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = allSystems;
      flake = {
        packages = forAllSystems (system: {
          gwq = inputs.nixpkgs.legacyPackages.${system}.callPackage ./modules/git/gwq/drv.nix {
            src = inputs.gwq;
          };
        });

        devShells = forAllSystems (system: {
          default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
            packages = [
              inputs.nixpkgs.legacyPackages.${system}.nix-update
            ];
          };
        });

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
        darwinModules.bootstrap = { ... }: {
          imports = [
            ./bootstrap/modules/darwin.nix
          ];
        };
        darwinConfigurations = {
          private = forDarwinSystems (system:
            inputs.nix-darwin.lib.darwinSystem {
              modules = [
                ./darwin.nix
              ];
              specialArgs = mkSpecialArgs system;
            }
          );
        };

        apps = forDarwinSystems (system: {
          darwin-rebuild = {
            type = "app";
            program = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
          };
        });

        extraSpecialArgs = forAllSystems (system: mkSpecialArgs system);

        homeConfigurations = {
          private = forAllSystems (system:
            inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              modules = [
                ./home.nix
                inputs.sops-nix.homeManagerModules.sops
              ];
              extraSpecialArgs = mkSpecialArgs system;
            }
          );
        };
      };
    };
}
