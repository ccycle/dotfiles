{
  # The bootstrap flake exists to solve a "chicken-and-egg" problem with private repositories.
  #
  # The main `flake.nix` in the root directory depends on private inputs (like `codex` or `dotfiles-private`).
  # To fetch these private inputs, Nix needs authentication tokens (e.g., in `~/.config/nix/nix.conf` or `/etc/nix/access-tokens.conf`).
  # However, these tokens are themselves managed by `sops-nix`, which is part of the system configuration.
  #
  # If we try to build the main flake on a fresh machine without tokens:
  # 1. Nix tries to fetch all inputs (including private ones).
  # 2. Fetch fails because tokens are missing.
  # 3. We cannot build the system to provision the tokens.
  #
  # This `bootstrap/flake.nix` solves this by:
  # 1. Depending ONLY on public inputs (nixpkgs, nix-darwin, sops-nix).
  # 2. Importing necessary modules from the parent directory (via `src` input) to configure `sops-nix`.
  # 3. Provisioning the `access-tokens.conf` file.
  #
  # Maintenance:
  # - Keep this flake minimal — only what is strictly required for credential provisioning.
  # - Prefer stability over code reuse — self-contained is safer than shared abstractions.
  # - Focus on credentials — its only job is to provision secrets and configure Git access.
  #
  # Usage:
  #   nix run ./bootstrap -- switch --flake ./bootstrap
  #
  # After this runs successfully, tokens will be in place, and you can switch to the main flake:
  #   darwin-rebuild switch --flake .
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, ... }:
    let
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      forDarwinSystems = nixpkgs.lib.genAttrs darwinSystems;
      # Helper to load env for a specific system context if needed, though here we load it globally or per-system.
      # Since env-impure.nix depends on builtins.getEnv, it's evaluated at call time.
      env = import ./env-impure.nix;
    in
    {
      darwinModules.bootstrap = ./modules/darwin.nix;

      darwinConfigurations = {
        bootstrap = forDarwinSystems (system:
          nix-darwin.lib.darwinSystem {
            inherit system;
            modules = [
              self.darwinModules.bootstrap
            ];
            specialArgs = { inherit inputs system; } // env;
          }
        );
      };

      apps = forDarwinSystems (system: {
        default = {
          type = "app";
          program = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
        };
      });

      devShells = forDarwinSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          secrets = pkgs.mkShell {
            packages = with pkgs; [ rbw pinentry_mac ];
            shellHook = ''
              # Configure pinentry if not set
              if ! rbw config show | grep -q "pinentry"; then
                rbw config set pinentry "${pkgs.pinentry_mac}/bin/pinentry-mac"
              fi
              echo "Bitwarden shell ready. Run 'rbw login' to authenticate."
            '';
          };
        }
      );
    };
}
