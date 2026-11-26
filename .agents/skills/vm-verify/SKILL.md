---
name: vm-verify
description: Verify darwin-rebuild switch (macbook-air-m1 profile), dotfiles symlinks, and sops secret activation inside an ephemeral Apple Silicon macOS VM (Tart), without touching the host machine's $HOME or system. Safe to run from several worktrees at once. Use when validating dotfiles changes made in a git worktree.
---

# VM-Based darwin-rebuild Verification

`darwin-rebuild switch` mutates global host state: the single system profile,
`/etc`, launchd, and the shared `$HOME`. The `custom.dotfiles.dir` option (see
[modules/dotfiles/home.nix](../../../modules/dotfiles/home.nix)) bakes the
invoking checkout into every `mkOutOfStoreSymlink` target, so a switch from a
worktree repoints the host's symlinks. Home-manager activation alone is not
isolated either: it also changes the docker context, OrbStack settings, the rbw
config, and gui-domain launchd agents.

This skill runs the real activation inside a throwaway macOS VM instead.

## Two tiers

- **Build-only, unlimited parallelism:** for most parallel checks,
  [verify-change](../verify-change/SKILL.md) (`nix build --no-link`) is enough.
  It touches only the shared Nix store, whose per-path locks deduplicate
  concurrent builds of the same derivations.
- **Activation, at most 2 at once:** this skill. Use it when the change affects
  activation (symlinks, launchd, `/etc`, secrets), not just evaluation.

## Usage

Run from the repository root of the worktree you want to verify:

```bash
.agents/skills/vm-verify/scripts/run.sh [--rebuild-golden]
```

Pass `--rebuild-golden` after bumping the base image, or when the golden
image's store has drifted far from the current closure and per-run copies get
slow.

## Prerequisites

- Apple Silicon Mac.
- `tart`, `sshpass`, `sops`, and `age-keygen`. Tart and sshpass are declared in
  [modules/tart/darwin.nix](../../../modules/tart/darwin.nix); all four are
  installed by every profile.

Design rationale: [design.md](design.md).

## Out of Scope

- `mac-mini-m4` / `mac-mini-m4-pro` profiles. Their `custom.storage.volumes`
  point at a physically mounted external volume, which has no VM equivalent.
- The `.agents/skills/smoke-test-*` skills. `macbook-air-m1` enables none of their
  services.
- Services that need nested virtualization (OrbStack/Docker). macOS guests
  cannot host further VMs.
