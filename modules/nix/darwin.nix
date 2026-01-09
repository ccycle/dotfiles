{ config, lib, pkgs, inputs, username, ... }:

{
  imports = [
  ];

  nix.nixPath = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.channel.enable = false;

  nix.settings.trusted-users = [ username ];
}
