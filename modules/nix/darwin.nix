{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

{
  imports = [
  ];

  nix.nixPath = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.channel.enable = false;
  nix.settings.nix-path = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.settings.auto-optimise-store = true;

  nix.settings.trusted-users = [ username ];
}
