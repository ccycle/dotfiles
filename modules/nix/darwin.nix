{ config, lib, pkgs, inputs, username, ... }:

{
  imports = [
    ../../bootstrap/modules/nix/common.nix
  ];

  nix.nixPath = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.channel.enable = false;

  nix.settings.trusted-users = [ username ];
}
