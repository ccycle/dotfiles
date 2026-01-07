{ config, pkgs, inputs, system, ... }:

{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops
    ./modules/darwin.nix
  ];

  nixpkgs.hostPlatform = system;

  # Basic nix-darwin configuration
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.nixPath = pkgs.lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];

  system.stateVersion = 5;

  # Home Manager configuration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
}
