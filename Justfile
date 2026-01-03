# import 'dotfiles/modules/common/nodejs/npm-install/Justfile'

# Generate environment.nix from env-eval.nix
generate-env:
    nix eval --file env-impure.nix > generated/env.nix

# Generate node2nix files for npm-install
node2nix-npm-install:
    node2nix

fetch-age-key:
    mkdir -p ~/.config/sops/age
    rbw get dotfiles-age-key > ~/.config/sops/age/keys.txt
    chmod 600 ~/.config/sops/age/keys.txt

darwin-rebuild:
    sudo darwin-rebuild switch --flake ".#private.$(uname -m | sed 's/arm64/aarch64/')-darwin" --impure -L --show-trace
