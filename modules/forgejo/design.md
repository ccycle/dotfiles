# Forgejo Module Design

## Why This Structure

**The SQLite DB sits on a Docker named volume, split out from the bulk
git data.** Forgejo's data tree mixes two very different things: bulk
git content (repositories, LFS objects, SSH host keys) and a small
SQLite database plus app state (config, attachments, sessions, queues,
indexers). The bulk content stays on the external drive via the
existing host bind mount — it's large, and it isn't SQLite, so
virtiofs is fine for it. The SQLite portion is overridden by a second,
more specific named-volume mount nested inside the same tree, moving
only the DB onto VM-internal storage. This is the same underlying fix
as `modules/pocket-id/design.md` (host bind mounts on OrbStack are
served over virtiofs, and SQLite crashes with `SQLITE_BUSY` /
`SQLITE_IOERR_SHMLOCK` there as soon as a second process opens the
live DB), applied as a split rather than a full swap, since unlike
Pocket ID, most of Forgejo's data genuinely belongs on the external
drive.

The split relies on Docker mounting the more specific destination path
on top of the less specific one — the named volume shadows that one
subdirectory of the host bind mount. This was verified empirically
before relying on it: a fresh named volume mounted at that path is
auto-chowned to the container's app user by Forgejo's own entrypoint,
so no extra ownership handling was needed (unlike some other
named-volume migrations, Forgejo has no separate secret file that
needs its own bind mount).

## Rejected Alternatives

- **Moving all of `/data` (including git repositories and LFS objects)
  onto a named volume.** That data is large and not SQLite-fragile;
  keeping it on the external drive's host bind mount preserves
  host-visible backups and avoids consuming VM-internal disk space for
  content that doesn't need VM-internal storage.

## CI Runner: Host Execution, Config-File Registration

**The Actions runner (`runnerEnable`) runs jobs directly on the host
("host" label, no container isolation) rather than in a docker
container.** The whole point of running a runner on this always-on
Apple Silicon machine is to get a real `aarch64-darwin` `nix build` in
CI - a Linux container on this host can't produce that. Host execution
means job steps have full access to the machine; this is accepted here
because it's a single-user home server, not a multi-tenant CI farm, and
is why `runnerLabels` carries a doc warning against adding untrusted
workflows.

**Registration goes through `config.yaml`'s `server.connections` map
via `forgejo forgejo-cli actions register`, not the deprecated
`forgejo-runner register` subcommand.** The runner binary's own
`register` command is flagged deprecated upstream in favor of declaring
connections directly in the config file. The bootstrap script generates
a 40-hex-char secret once (`forgejo-cli actions generate-secret`,
guaranteed to match the format the server expects), persists it under
`runnerDataDir`, and re-runs `forgejo-cli actions register` on every
boot - that subcommand is documented as idempotent, so repeating it
with the same secret is safe and picks up label/name changes from a
rebuild without a manual re-registration step.

**Both `forgejo-cli` calls run as `-u git`, not the exec default.**
`docker compose exec` without `-u` attaches as root, and any
state-mutating `forgejo`/`forgejo-cli` subcommand (as opposed to
`--help`) fatally refuses to run as root at startup
(`MustInstalled()`'s root check) - confirmed by `tests/e2e-forgejo`
hitting exactly this before `-u git` was added. The existing
`forgejo dump` call in the backup job already had this right; the two
`forgejo-cli` calls here didn't, and would have crashed the exec (not
the server itself) on every real deployment.

**Branch protection has no "block force push" field to set.** The
Forgejo/Gitea branch-protection API (verified against the
`forgejo-sdk` Go struct, and confirmed empirically by `tests/e2e-forgejo`

- a force-push to a branch with only `enable_push`/`enable_status_check`
  set is in fact rejected) has no `enable_force_push`/`block_force_push`
  option; force-pushing a protected branch is simply disallowed as an
  inherent property of branch protection. `enable_push: true` +
  `enable_status_check: true` is what encodes "direct push allowed, CI
  required" here.

**`statusCheckContexts` has no default.** Per this repo's "no default
fallbacks for critical configuration" convention: the config value is
per-repo and per-workflow, so there's no single correct default to fall
back to, and `tests/e2e-forgejo` empirically confirmed the format is
`"<workflow name> / <job id> (<event>)"` (observed `"E2E / verify
(push)"` for a workflow named "E2E" with job id "verify"). Each new
`branchProtections` entry still needs its own value filled in by hand
from that pattern (or confirmed against the repo's Checks UI) - an
incorrect value here would silently block every merge on a check that
never reports.

## Push Mirror: GUI-Based Setup

**Push mirrors are set up via the Forgejo web UI, not the API.**
The `forgejo-mirror-bootstrap` daemon's role is limited to ensuring
mirrors configured in `services.forgejo.pushMirrors` exist on boot —
it skips repos that already have one, so GUI-created mirrors are
left untouched.

### Initial Setup

1. Create the target repo on GitHub (empty, same name).
2. In Forgejo, open the repo > **Settings** > **Repository** > **Mirror Settings**.
3. Fill in:
   - **Git Remote Repository URL**: `https://github.com/<org>/<repo>.git`
   - **Authorization**: Username = `x-access-token`, Password = `<GitHub PAT>`
   - **Sync when new commits are pushed**: checked
4. Click **Add Push Mirror**.

### Token Rotation

1. In Forgejo, open the repo > **Settings** > **Repository** > **Mirror Settings**.
2. Delete the existing push mirror.
3. Add a new push mirror with the new PAT (same steps as initial setup).

No rebuild or restart required — the change takes effect immediately.

### Verification

- **GUI**: Repo > Settings > Mirror Settings shows the active mirror.
- **API**: `curl -s -H "Authorization: token $FORGEJO_TOKEN" http://127.0.0.1:3000/api/v1/repos/<org>/<repo>/push_mirrors | jq .`
- **Logs**: `tail -50 /var/log/forgejo-mirror-bootstrap.log`

## Backup: `forgejo dump` via the Existing Bind Mount

**The daily backup job writes into `dataDir/dumps` instead of a
separate volume.** `forgejo dump` runs inside the container with
`--file /data/dumps/...`, and `/data` is already the bind-mounted
external drive (see above), so the dump lands directly on host-visible,
already-backed-up storage with no extra `docker cp` step or volume
declaration. Retention pruning (`backupRetentionCount` generations) runs
on the host side against that same path for the same reason.
