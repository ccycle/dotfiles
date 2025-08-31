# import 'dotfiles/modules/common/nodejs/npm-install/Justfile'

# Generate environment.nix from env-eval.nix
# generate-env: env-impure.nix
generate-env: "env-impure.nix"
    nix eval --file env-impure.nix > generated/env.nix

# Generate node2nix files for npm-install
node2nix-npm-install:
    node2nix
