#!/bin/sh
nix --extra-experimental-features "nix-command flakes" --option filter-syscalls false run .#homeConfigurations.x86_64-linux.dotfiles-test.activationPackage