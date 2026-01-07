{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ../../bootstrap/modules/nix/common.nix
  ];

  nix.nixPath = lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.channel.enable = false;
}
