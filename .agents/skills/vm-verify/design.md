# vm-verify Design

## Why This Structure

The closure is built on the host, so the guest needs no Nix cache access (Attic or its CA) and parallel runs share host-side work.
The guest configuration is the committed profile extended with `extendModules`: the user becomes the base image's `admin`, `custom.dotfiles.dir` points at the guest's copy, and the sops secrets are re-pointed.
No flake input is overridden, so the flake itself stays exactly what comin deploys.
comin is disabled in the guest, because it would otherwise pull the default branch and switch the VM away from the change under test.

Each run clones a golden image with an APFS copy-on-write clone and deletes the clone on exit.
Only the store delta since the golden image was seeded is copied, and disk use stays at about one golden image instead of one VM per worktree.

Concurrent runs are capped host-wide because [Apple's Virtualization framework refuses a third running macOS guest](https://developer.apple.com/documentation/virtualization/vzerror/virtualmachinelimitexceeded).
Extra runs wait instead of failing at boot.
VMs started outside this skill count against the limit, but the slots do not see them.

Every sops secret the guest declares is re-pointed at dummy values encrypted for a per-run age key.
The real age key and rbw never reach the VM, yet the sops-nix activation path is still exercised.

## Constraints

- `nix copy` starts the guest daemon through sudo, which makes the connection trusted, so unsigned host-built paths are accepted without editing the guest's `nix.conf`; nix-darwin aborts on an unknown `nix.conf`.
- The base image's default disk cannot hold the closure on top of macOS. The enlarged disk file is sparse, so the host pays only for used blocks.
- The guest may already have grown its APFS container at boot, in which case resizing errors; the free-space check decides instead.
- Upstream Nix is installed rather than Determinate, because nix-darwin refuses to activate alongside the Determinate daemon.
- The Nix installer edits the guest's `/etc/bashrc` and `/etc/zshrc`, which nix-darwin refuses to overwrite, so they are renamed. Guest commands use absolute Nix paths and do not depend on them.
