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
    nix-claude-code.url = "github:ryoppippi/nix-claude-code";
    devx.url = "github:input-output-hk/devx";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    fresh.url = "github:sinelaw/fresh/v0.4.4";
    fresh.inputs.nixpkgs.follows = "nixpkgs";
    ghc-wasm-meta.url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
    ghcup.flake = false;
    ghcup.url = "github:haskell/ghcup-hs";
    ghq-migrator.flake = false;
    ghq-migrator.url = "github:astj/ghq-migrator";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    gitui.url = "github:extrawurst/gitui";
    gitui.flake = false;
    gcx.url = "github:grafana/gcx";
    gcx.flake = false;
    gwq.url = "github:d-kuro/gwq";
    gwq.flake = false;
    herdr.url = "github:ogulcancelik/herdr";
    herdr.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.follows = "bootstrap/home-manager";
    hunk.url = "github:modem-dev/hunk";
    hunk.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.follows = "bootstrap/nix-darwin";
    nixpkgs-2211.url = "github:nixos/nixpkgs/22.11";
    nixpkgs-2305.url = "github:nixos/nixpkgs/23.05";
    nixpkgs-2311.url = "github:nixos/nixpkgs/23.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/24.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/24.11";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/25.05";
    nixpkgs-2511.url = "github:NixOS/nixpkgs/25.11";
    nixpkgs-2605.url = "github:NixOS/nixpkgs/26.05";
    # Pinned independently of the main `nixpkgs` input so bumping it (to
    # keep playwright-driver's bundled Chromium in lockstep with
    # tests/e2e/package.json's @playwright/test version) never needs to
    # wait on, or ride along with, an unrelated main nixpkgs bump.
    # See tests/e2e/design.md.
    nixpkgs-playwright.url = "github:nixos/nixpkgs/26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/26.05";
    ghostty.url = "github:ghostty-org/ghostty";
    # opencode.url = "github:anomalyco/opencode/dev";
    pi.url = "github:lukasl-dev/pi.nix";
    stylix.url = "github:nix-community/stylix/release-26.05";
    tailscale.url = "github:tailscale/tailscale/v1.92.5";
    pip2nix.url = "github:nix-community/pip2nix";
    pyzotero-cli.flake = false;
    pyzotero-cli.url = "github:chriscarrollsmith/pyzotero-cli";
    serena.url = "github:oraios/serena";
    sops-nix.url = "github:Mic92/sops-nix";
    dotfiles-config.url = "path:./modules/dotfiles/default-config";
    storage-config.url = "path:./modules/storage/default-config";
    obsidian-vault-config.url = "path:./modules/obsidian/default-config";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    worktrunk.url = "github:max-sixty/worktrunk";
    worktrunk.inputs.nixpkgs.follows = "nixpkgs";
    workmux.url = "github:raine/workmux";
    workmux.inputs.nixpkgs.follows = "nixpkgs";
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

      # Only pass `inputs` itself and explicit derived values — do not spread inputs.
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
          herdrPackage = inputs.herdr.packages.${system}.default;
          hunkPackage = inputs.hunk.packages.${system}.default;
          piPackage = inputs.pi.packages.${system}.coding-agent;
          pkgs-2211 = mkPkgs inputs.nixpkgs-2211;
          pkgs-2305 = mkPkgs inputs.nixpkgs-2305;
          pkgs-2311 = mkPkgs inputs.nixpkgs-2311;
          pkgs-2405 = mkPkgs inputs.nixpkgs-2405;
          pkgs-2411 = mkPkgs inputs.nixpkgs-2411;
          pkgs-2505 = mkPkgs inputs.nixpkgs-2505;
          pkgs-2511 = mkPkgs inputs.nixpkgs-2511;
          pkgs-2605 = mkPkgs inputs.nixpkgs-2605;
          pkgs-unstable = mkPkgs inputs.nixpkgs-unstable;
          freshPackage = inputs.fresh.packages.${system}.default;
          worktrunkPackage = inputs.worktrunk.packages.${system}.default;
          workmuxPackage = inputs.workmux.packages.${system}.default;
          pyzoteroCliPackage = inputs.nixpkgs.legacyPackages.${system}.python3Packages.callPackage
            ./modules/python/pyzotero-cli/drv.nix
            { src = inputs.pyzotero-cli; };
        } // env;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = allSystems;
      flake = {
        packages = forAllSystems (system: {
          gwq = inputs.nixpkgs.legacyPackages.${system}.callPackage ./modules/git/gwq/drv.nix {
            src = inputs.gwq;
          };
          gcx = inputs.nixpkgs.legacyPackages.${system}.callPackage ./modules/grafana/drv.nix {
            src = inputs.gcx;
          };
          gitui = inputs.nixpkgs.legacyPackages.${system}.callPackage ./modules/gitui/drv.nix {
            src = inputs.gitui;
          };
          pyzotero-cli = inputs.nixpkgs.legacyPackages.${system}.python3Packages.callPackage ./modules/python/pyzotero-cli/drv.nix {
            src = inputs.pyzotero-cli;
          };
        });

        formatter = forAllSystems (system: inputs.nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

        devShells = forAllSystems (system: {
          default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
            packages = [
              inputs.nixpkgs.legacyPackages.${system}.nix-update
            ];
          };
          e2e = inputs.nixpkgs.legacyPackages.${system}.mkShell {
            packages = [
              inputs.nixpkgs.legacyPackages.${system}.nodejs
            ];
            shellHook = ''
              export PLAYWRIGHT_BROWSERS_PATH=${inputs.nixpkgs-playwright.legacyPackages.${system}.playwright-driver.browsers}
              export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            '';
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
        # `private` uses forDarwinSystems, so the attr path includes the arch
        # (e.g. .private.aarch64-darwin.system).
        # `mac-mini-m4` / `mac-mini-m4-pro` call darwinSystem directly,
        # so there is no arch suffix (e.g. .mac-mini-m4.system).
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
