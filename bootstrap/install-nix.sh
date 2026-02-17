#!/bin/sh

if [ "$(which nix)" = "" ]; then
    # https://github.com/NixOS/nix-installer
    curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install
else
    echo "Nix is already installed; Aborting"
fi