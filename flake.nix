{
  # Main system configuration flake.
  #
  # NOTE: If this is a fresh installation and you have private flake inputs,
  # you MUST run the bootstrap flake first to provision access tokens.
  #
  # See `bootstrap/flake.nix` for details.
  inputs = {
    attic.url = "github:zhaofengli/attic";
    bootstrap.url = "path:./bootstrap";
    brew-nix.url = "github:BatteredBunny/brew-nix";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    devx.url = "github:input-output-hk/devx";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    fresh.flake = false;
    fresh.url = "github:sinelaw/fresh";
    ghc-wasm-meta.url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
    ghcup.flake = false;
    ghcup.url = "github:haskell/ghcup-hs";
    ghq-migrator.flake = false;
    ghq-migrator.url = "github:astj/ghq-migrator";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    gitui.url = "github:extrawurst/gitui";
    gitui.flake = false;
    gwq.url = "github:d-kuro/gwq";
    gwq.flake = false;
    home-manager.follows = "bootstrap/home-manager";
    nix-darwin.follows = "bootstrap/nix-darwin";
    nixpkgs-2211.url = "github:nixos/nixpkgs/22.11";
    nixpkgs-2305.url = "github:nixos/nixpkgs/23.05";
    nixpkgs-2311.url = "github:nixos/nixpkgs/23.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/24.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/24.11";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/25.05";
    nixpkgs-2511.url = "github:NixOS/nixpkgs/25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/25.11";
    ghostty.url = "github:ghostty-org/ghostty";
    # opencode.url = "github:anomalyco/opencode/dev";
    stylix.url = "github:nix-community/stylix/release-25.11";
    tailscale.url = "github:tailscale/tailscale/v1.92.5";
    pip2nix.url = "github:nix-community/pip2nix";
    serena.url = "github:oraios/serena";
    sops-nix.url = "github:Mic92/sops-nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    worktrunk.flake = false;
    worktrunk.url = "github:max-sixty/worktrunk";
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
        {
          inherit inputs;
          inherit system;
          tailscalePackage = inputs.tailscale.packages.${system}.tailscale;
          gituiPackage = inputs.nixpkgs.legacyPackages.${system}.callPackage
            ./modules/gitui/drv.nix
            { src = inputs.gitui; };
          pkgs-2211 = mkPkgs inputs.nixpkgs-2211;
          pkgs-2305 = mkPkgs inputs.nixpkgs-2305;
          pkgs-2311 = mkPkgs inputs.nixpkgs-2311;
          pkgs-2405 = mkPkgs inputs.nixpkgs-2405;
          pkgs-2411 = mkPkgs inputs.nixpkgs-2411;
          pkgs-2505 = mkPkgs inputs.nixpkgs-2505;
          pkgs-2511 = mkPkgs inputs.nixpkgs-2511;
          pkgs-unstable = mkPkgs inputs.nixpkgs-unstable;
          freshPackage = inputs.nixpkgs.legacyPackages.${system}.callPackage
            ./modules/fresh/drv.nix
            { src = inputs.fresh; };
          worktrunkPackage = inputs.nixpkgs.legacyPackages.${system}.callPackage
            ./modules/worktrunk/drv.nix
            { src = inputs.worktrunk; };
        } // env;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = allSystems;
      flake = {
        packages = forAllSystems (system: {
          gwq = inputs.nixpkgs.legacyPackages.${system}.callPackage ./modules/git/gwq/drv.nix {
            src = inputs.gwq;
          };
          gitui = inputs.nixpkgs.legacyPackages.${system}.callPackage ./modules/gitui/drv.nix {
            src = inputs.gitui;
          };
        });

        devShells = forAllSystems (system: {
          default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
            packages = [
              inputs.nixpkgs.legacyPackages.${system}.nix-update
            ];
          };
        });

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
          "mac-mini-m4" = inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            modules = [
              ./darwin.nix
              ./modules/mac-mini-m4/darwin.nix
            ];
            specialArgs = mkSpecialArgs "aarch64-darwin";
          };
          "mac-mini-m4-pro" = inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            modules = [
              ./darwin.nix
              ./modules/mac-mini-m4-pro/darwin.nix
            ];
            specialArgs = mkSpecialArgs "aarch64-darwin";
          };
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
