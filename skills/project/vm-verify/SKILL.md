---
name: vm-verify
description: Verify darwin-rebuild switch (private profile) and dotfiles symlink correctness inside an isolated Apple Silicon macOS VM (Tart), without touching the host machine's $HOME. Use when validating dotfiles changes made in a git worktree.
---

# VM-Based darwin-rebuild Verification

`darwin-rebuild switch` mutates the single shared `$HOME` on the host machine: the
`custom.dotfiles.dir` option (see `modules/dotfiles/home.nix`) bakes the invoking
`repo_root` into every `mkOutOfStoreSymlink` target (Claude skills/settings/hooks,
ai-rules files, herdr config, direnv). Running it directly from a git worktree
repoints those symlinks away from the main checkout and corrupts the host's real
state. `.local/` is also gitignored, so it never exists in a fresh worktree.

This skill sidesteps both problems by running the real `darwin-rebuild switch`
inside a disposable macOS VM (via [Tart](https://tart.run/)) that has its own
independent `$HOME`. The VM never touches the host's `$HOME`, so it's safe to run
from any worktree without affecting the main checkout or other worktrees.

## Prerequisites

- Apple Silicon Mac (Tart requires an Apple Silicon host to run macOS guests).
- [Tart](https://tart.run/) and `sshpass` (used to authenticate against the
  default `admin`/`admin` credentials on Cirrus Labs' base image). Both are
  declared in `modules/tart/darwin.nix` and installed automatically by
  `darwin-rebuild switch` for the `private` profile — no manual `brew install`
  needed. `tart` is packaged in nixpkgs under a Fair Source license (`unfree`),
  allowed via a predicate scoped to just that package.

## Usage

Run from the repository root of the worktree you want to verify:

```bash
skills/project/vm-verify/scripts/run.sh
```

The script always targets the `private` profile and always operates on whichever
worktree it's invoked from (it resolves its own path via `$0`, not a hardcoded
location).

## What It Does

1. Clones a fresh VM from Cirrus Labs' official macOS base image
   (`ghcr.io/cirruslabs/macos-sequoia-base:latest`) and boots it headless.
2. `rsync`s the current worktree into the VM over SSH (excluding `.git`; `.local/`
   is gitignored so it's never transferred — no host-local secrets or paths leak
   into the VM).
3. Installs Nix inside the VM (Determinate Systems installer, non-interactive).
4. Runs `scripts/darwin-rebuild.sh private` inside the VM. This lets the existing
   `.local/dotfiles/flake.nix` auto-creation logic
   (`scripts/darwin-rebuild.sh:88-104`) run unmodified, wiring
   `custom.dotfiles.dir` to the VM-local copy of the worktree.
5. Verifies that the key `mkOutOfStoreSymlink` targets (Claude skills/settings/
   hooks, ai-rules files, herdr config, direnv) resolve into the VM's copy of the
   worktree, not somewhere stale or broken.
6. Always tears the VM down (`tart stop` + `tart delete`) on exit, success or
   failure.

## Known Constraints

- Apple limits macOS VM concurrency to **2 per host at the kernel level**
  ([source](https://cirrus-ci.org/blog/2022/07/07/isolating-network-between-tarts-macos-virtual-machines/)).
  A third concurrent `vm-verify` run will fail at VM boot. This skill does not
  queue or serialize runs — coordinate manually across worktrees.
- Every run re-installs Nix from scratch inside a fresh VM clone, so a full run
  takes several minutes. There is no prepared/cached base image in this
  implementation.

## Out of Scope

- `mac-mini-m4` / `mac-mini-m4-pro` profiles (they require `.local/storage`
  pointing at a physically mounted external volume, which has no VM-local
  equivalent here).
- The existing `skills/project/smoke-test-*` skills — `private` enables none of
  the services they check, so they don't apply.

## When to Use

- After making dotfiles changes in a git worktree, to confirm `darwin-rebuild
  switch` and the resulting symlinks actually work — without risking the host's
  `$HOME` or colliding with other worktrees doing the same thing in parallel (up
  to the 2-VM concurrency limit).
