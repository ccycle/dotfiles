{ config, pkgs, inputs, system, ... }:

{
  nixpkgs.hostPlatform = system;

  # Basic nix-darwin configuration
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.nixPath = pkgs.lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];

  system.stateVersion = 5;
}
