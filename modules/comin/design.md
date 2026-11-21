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

## Auth: access tokens, not SSH deploy keys

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

So both remotes authenticate over HTTPS with a read-only,
repo-scoped access token (`auth.access_token_path`, sops-managed, see
[modules/comin/secrets.yaml](secrets.yaml)). Commit-signature verification is
unaffected by this - `sshAllowedSignersPath` verifies the commit
object itself after fetch, independent of which transport/auth moved
the bytes.

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
`dotfiles-config`) has been removed — comin's pure evaluation cannot
see gitignored files, and unifying the username across all machines
eliminates the need for per-machine identity overrides.

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
