{ config, pkgs, inputs, system, ... }:

let
  env = if builtins.pathExists ./generated/env.nix then import ./generated/env.nix else import ./env-impure.nix;

  mkPkgs = input: input.legacyPackages.${system};

  # Reconstruct the arguments expected by modules.nix
  extraSpecialArgs = inputs // {
    inherit (inputs) self;
    pkgs-2211 = mkPkgs inputs.nixpkgs-2211;
    pkgs-2305 = mkPkgs inputs.nixpkgs-2305;
    pkgs-2311 = mkPkgs inputs.nixpkgs-2311;
    pkgs-2405 = mkPkgs inputs.nixpkgs-2405;
    pkgs-2411 = mkPkgs inputs.nixpkgs-2411;
    pkgs-2505 = mkPkgs inputs.nixpkgs-2505;
    pkgs-unstable = mkPkgs inputs.nixpkgs-unstable;
  } // env;

in
{
  imports = [
    ./modules/cachix/darwin.nix
    ./bootstrap/modules/cachix/darwin.nix
    ./modules/nix/darwin.nix
    ./modules/tailscale/darwin.nix
    ./modules/ssh/darwin.nix
  ];

  # Required for launchd.user.agents
  system.primaryUser = env.username;

  nix.settings.trusted-users = [ env.username ];

  users.users."${env.username}" = {
    home = env.homeDirectory;
    shell = pkgs.zsh;
  };

  # Set Zsh as the default shell for the system and ensure it's in /etc/shells
  programs.zsh.enable = true;

  # Home Manager configuration
  home-manager.extraSpecialArgs = extraSpecialArgs;
  home-manager.users."${env.username}" = {
    imports = [
      ./home.nix
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}
