# herdr Design

## Purpose

Install herdr itself and its repo-managed configuration declaratively, while herdr plugins stay outside every `darwin-rebuild` and comin deploy.

## Non-Goals

- Installing, updating, or pinning herdr plugins during activation.
- Packaging herdr plugins as Nix derivations.

## Why This Structure

herdr plugins are installed by `herdr plugin install`, which clones a GitHub repository and runs the plugin's own build steps (shell scripts that download or compile binaries).
That is a network fetch plus arbitrary upstream code, and it used to run inside home-manager activation on every deploy.
Activation had no timeout, so a hung fetch or build stalled the whole deploy, and an install failure only printed a warning that nobody read in the comin log.
Plugins are therefore installed by a script the user runs by hand.
A broken plugin now shows up where the user is looking, and it cannot block configuration changes from reaching the hosts.

Plugin configuration files stay declarative.
They are plain symlinks into the repository and cannot fail a build.
They are also harmless when the plugin is not installed yet.

The pi agent-state integration stays in activation.
`herdr integration install` only writes a local file from the herdr binary already in the closure, so it has no network or upstream-build failure mode.

## Rejected Alternatives

- **Package plugins with Nix outside the system closure** (a separate flake output built on demand): upstream ships plugins as herdr-managed checkouts with their own build scripts, not as source Nix can build reproducibly.
  Wrapping them would add fixed-output hashes to maintain for every upstream release, and that is exactly the kind of breakage this design avoids.
- **Keep activation but guard it with a timeout**: that limits the delay, but the deploy still depends on GitHub and upstream scripts, and a failure is still easy to miss.

## Trade-offs

Plugin versions are no longer declared or pinned in the repository.
A fresh machine has no plugins until the install script runs, and each host can drift to whatever upstream version it last updated to.
This is accepted because plugins were never pinned before either: activation installed the latest upstream version.
