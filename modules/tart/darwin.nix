{ lib, pkgs, ... }:
{
  # tart (Cirrus Labs' macOS VM tool) is Fair Source licensed, so nixpkgs marks it
  # unfree. Scope the allowance to just "tart" rather than flipping allowUnfree
  # globally.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "tart" ];

  environment.systemPackages = [
    pkgs.tart
    pkgs.sshpass # non-interactive ssh auth against Tart VM guests, used by skills/project/vm-verify
  ];
}
