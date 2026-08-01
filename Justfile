# import 'dotfiles/modules/common/nodejs/npm-install/Justfile'

# Generate environment.nix from env-eval.nix
generate-env:
    nix eval --file env-impure.nix > generated/env.nix

# Generate node2nix files for npm-install
node2nix-npm-install:
    node2nix

darwin-rebuild:
    sudo darwin-rebuild switch --flake ".#private.$(uname -m | sed 's/arm64/aarch64/')-darwin" --impure -L --show-trace

update-gwq:
    nix flake lock --update-input gwq
    nix develop --command nix-update --flake .#gwq --version=skip

# Install repo-local git hooks (run once after cloning)
install-git-hooks:
    git config core.hooksPath scripts/git-hooks

# Inspect herdr worktrees whose branches are already merged to main
cleanup-worktrees-dry-run:
    ./scripts/cleanup-merged-worktrees.sh --dry-run

# Classify and remove the CURRENT worktree (interactive, safe-only)
cleanup-worktree:
    ./scripts/cleanup-worktree.sh

# Classify the current worktree without removing
cleanup-worktree-dry-run:
    ./scripts/cleanup-worktree.sh --dry-run

# Preview stale worktrees (no diff from main / old + no activity)
stale-worktrees:
    ./scripts/detect-stale-worktrees.sh
