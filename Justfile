# import 'dotfiles/modules/common/nodejs/npm-install/Justfile'

# Generate environment.nix from env-eval.nix
generate-env:
    nix eval --file env-impure.nix > generated/env.nix

# Generate node2nix files for npm-install
node2nix-npm-install:
    node2nix

darwin-rebuild:
    .agents/skills/darwin-rebuild/scripts/darwin-rebuild.sh

update-gwq:
    nix flake lock --update-input gwq
    nix develop --command nix-update --flake .#gwq --version=skip

# Install repo-local git hooks (run once after cloning)
install-git-hooks:
    git config core.hooksPath hooks
