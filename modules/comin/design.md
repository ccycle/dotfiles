# comin Design

## Purpose

Pull-based GitOps for the two always-on, single-purpose mac minis
(`mac-mini-m4`, `mac-mini-m4-pro`). A comin launchd daemon polls this
repo's remotes and auto-deploys `darwinConfigurations.<hostname>` on
push to `main`, replacing manual `darwin-rebuild switch` for these two
hosts only. `private` (the portable, multi-machine profile) is
untouched and keeps manual rebuild.

## Remote ordering and the self-hosting loop

`services.comin.remotes` is ordered Forgejo-first, GitHub-second.
Forgejo (`modules/forgejo`) is itself managed by this repo, so a
Forgejo-only remote would be a single point of failure with a
self-hosting loop: if a bad commit breaks Forgejo, comin could never
fetch the fix that repairs it. The GitHub remote breaks that loop -
comin still has a path to a working commit even if Forgejo is down.
A local bare-path remote (comin's own "iterate faster" howto) was
rejected: it adds attack surface (a local remote comin trusts
implicitly) for a benefit (faster local iteration) this deployment
doesn't need.

## Auth: anonymous HTTPS, not SSH deploy keys or tokens

The original plan was SSH deploy keys, matching this repo's existing
SSH-based tooling. That doesn't work here:

- comin's fetcher (`internal/repository/git.go`) only attaches SSH
  `PublicKeys` auth when using go-git's SSH transport, which requires
  an `ssh://`/`git@`-style remote URL. Both remotes are `https://`
  (see `git remote -v`), so SSH deploy keys have no transport to
  attach to.
- Even switching remote URLs to SSH doesn't work for Forgejo: its SSH
  port is loopback-bound only (`127.0.0.1:2223`, see
  [modules/forgejo/compose.yaml](../forgejo/compose.yaml) and [modules/forgejo/design.md](../forgejo/design.md)) -
  a deliberate security choice, not something this task should
  reverse. `mac-mini-m4` (a different physical host) can't reach it
  over Tailscale regardless of remote URL scheme.

Both repos are publicly readable, so both remotes fetch over HTTPS
anonymously. Read-only access tokens were the next plan and were
rejected after they shipped as sops placeholders: comin then failed
every fetch with "authentication required", and no deployment
happened until someone read the log. A token adds a secret to rotate
but protects nothing here: fetch auth only gates reading public code.
Trust comes from commit-signature verification -
`sshAllowedSignersPath` verifies the commit object itself after fetch,
independent of which transport moved the bytes.

Non-goal: private repos. Making either repo private requires
reintroducing per-remote tokens.

## Commit signature verification

Required and SSH-based (`services.comin.sshAllowedSignersPath`),
reusing the repo's existing SSH commit-signing setup (`gpg.format=ssh`
in `modules/git/gitconfig`) rather than a second trust root. Necessary
because this is unattended pull-and-switch with no human in the loop:
a compromise of either git host, or a rollback after `/var/lib/comin`
loss (comin only remembers the last deployed commit there - see
comin's own howtos.md), would otherwise auto-deploy silently.
[modules/comin/darwin.nix](darwin.nix) copies the signing public key content into
`/etc/comin/allowed_signers` (system-readable) rather than pointing at
the user's home-manager-deployed `~/.config/git/allowed_signers`,
since comin runs as a root launchd daemon outside any user session.

## The `.local/storage` / `.local/user` constraint

comin evaluates the flake via `git+file://<repo>?rev=<sha>` - a
content-addressed fetch from git history at that commit, not a
read of the working tree. Gitignored files (`.local/storage`,
`.local/user`, etc., which `scripts/darwin-rebuild.sh` used to
inject via `--override-input`) are therefore invisible to comin no
matter what exists on disk beside its clone. Confirmed empirically:
`nix eval` against `darwinConfigurations.mac-mini-m4{,-pro}` with no
overrides (comin's exact invocation - see `internal/executor/utils.go`,
which hardcodes `--extra-experimental-features "flakes nix-command"
--accept-flake-config` and nothing else) fails on the
`custom.storage.volumes.*` and `username` assertions that `.local/*`
normally satisfies.

Confirmed there is no configuration-level substitute for
`--override-input`/`--impure` here: comin's own Go source and Nix
module options expose no extra-nix-args option; `nix.conf` has no
`override-input`-equivalent setting at all; `NIX_CONFIG="pure-eval =
false"` in comin's daemon environment does not lift the `--impure`-only
restriction on absolute-path reads (tested directly); and the flake
registry mechanism doesn't apply to `path:`-type inputs resolved
relative to the flake's own source tree (confirmed via `flake.lock`,
which locks each of `storage-config`/`user-config`/`dotfiles-config` to
that literal relative path, not a content hash - there is nothing for a
registry to redirect). A `builtins.fetchGit` call embedded in a git
submodule was also considered (comin's `submodules` option merely adds
`?submodules=1` to the flake URL, delegating the actual fetch to Nix's
own git fetcher - not comin-specific auth) but rejected: it carries the
same rev-bump cost as the mechanism below, while adding a mandatory
manual `git submodule update --init` step for every human-run switch
too.

### Chosen mechanism: direct commit

All profiles share the anonymous username `ccycle` (hardcoded in
`mkSpecialArgs` in `flake.nix`). Per-host values
(`custom.storage.volumes`, `custom.dotfiles.dir`) are committed
directly in each host's `darwin.nix` via `lib.mkDefault`. The former
`.local/*` override-input mechanism (`user-config`, `storage-config`,
`dotfiles-config`, and later `obsidian-vault-config`) has been removed —
comin's pure evaluation cannot see gitignored files, and unifying the
username across all machines eliminates the need for per-machine identity
overrides. `verify-change` rejects any reintroduced `--override-input`.

A private `builtins.fetchGit`-based repo was evaluated and rejected:
it carried a rev-pinning cost on every value change, forced a
two-stage bootstrap (token provisioning before host evaluation), and
added a `private`-profile sops recipient dependency — all to hide
infrastructure topology (username, drive labels) that is not secret.

## Bootstrap

The first `services.comin.enable = true` deploy still goes through
manual `sudo darwin-rebuild switch` (chicken-and-egg: comin itself
ships via a rebuild). comin takes over polling after that. The
`darwin-rebuild` app/Justfile recipe stays for `private` and for
this one-time bootstrap.

## Skip the deprecated `activate-user`

comin's Darwin deploy runs `activate-user` and then `activate`.
Since nix-darwin made user activation part of `activate`,
`activate-user` is a stub marked `# nix-darwin: deprecated` that does
nothing but print a deprecation warning, and nix-darwin advises
deployment tools to skip it.
Under comin's launchd `PATH` (nix, git, openssh only) the stub also
fails to find `grep` on its upgrade check, which exits 0 and logs
`grep: command not found` on every deploy.
[skip-activate-user.patch](skip-activate-user.patch) removes the call
from comin.
Adding `grep` to the daemon `PATH` was rejected: the stub would still
do nothing, and print a longer deprecation warning instead.
The patch can go once upstream comin stops calling `activate-user`.

## No `/Applications/Nix Apps` on comin hosts

nix-darwin aborts activation unless it can write into every bundle in
`/Applications/Nix Apps` (`ensureAppManagement` in nix-darwin's
`modules/system/applications.nix`).
The bundles there are vendor-notarized brew-nix casks, so macOS gates
that write behind the App Management TCC permission.
comin is a system launchd daemon outside any GUI session, so every
deploy failed with "permission denied when trying to update apps over
SSH", even with nobody on SSH.
[darwin.nix](darwin.nix) therefore replaces `system.build.applications`
with an empty tree on every host that enables comin.
Packages stay in `environment.systemPackages`, so their CLIs and the
services that launch a bundle from its `/nix/store` path keep working;
only the copies in `/Applications` go away.

Rejected: granting App Management or Full Disk Access to comin.
TCC keys a grant for a bare binary to its path and its ad-hoc cdhash,
so it would have to be re-granted from a GUI session on every comin
rebuild, and comin's makeWrapper script would put the grant on a
shared Nix bash that every script using it inherits.
Rejected: moving the apps to Homebrew casks, which leaves `brew` to
modify notarized bundles from the same daemon context and most likely
meets the same App Management gate (untested).

The bundles already in `/Applications/Nix Apps` still trip the check
before activation can remove them, so a host needs one
`darwin-rebuild switch` from a GUI session after this lands.
