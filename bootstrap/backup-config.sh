#!/bin/bash
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin
sudo mv /etc/nix/nix.custom.conf{,.before-nix-darwin}