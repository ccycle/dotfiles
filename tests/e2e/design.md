# E2E Test Suite Design

## Purpose

Provide browser-driven E2E coverage for services fronted by Pocket ID's
passkey-only OIDC (`modules/pocket-id`), starting with OpenCloud: the
full passkey login ceremony (something a Nix build check or a
health-endpoint smoke test structurally cannot exercise — it requires a
real browser, a real (virtual) WebAuthn authenticator, and a real OIDC
redirect round trip) and OpenCloud's posix-driver promise that the host
filesystem tree mirrors the UI (`modules/opencloud/design.md`).

## Non-Goals

- Services beyond OpenCloud (Immich, Grafana, Forgejo, GitLab) — the
  passkey-auth helper (`lib/pocket-id-auth.ts`) is written to be reusable
  for them, but no spec exists yet.
- CI integration. GitHub Actions' `ubuntu-latest` runner has no Docker
  access to the real stack and can't run this. A self-hosted Forgejo
  Actions runner on the actual Mac could, in principle, reuse this design
  unmodified (same localhost-only stack, same persisted-bootstrap data
  dir), but no such runner is confirmed to exist in this repo's Nix
  config today — revisit when that's set up.
- Testing against production. This suite never touches the real
  `services.pocket-id`/`services.opencloud` instances or their data.

## Why a Per-Worktree Isolated Stack, Not Production, Not a Shared Instance, Not a VM

Three earlier designs were rejected in favor of this one:

- **Testing against the real production instance** (disposable users
  against the live Pocket ID/OpenCloud) was the original plan, but it
  means every test run touches production auth state.
- **A VM replicating the full production stack** (`skills/project/
  vm-verify`'s approach) is impossible for this specific case: Apple
  Silicon's Virtualization.framework does not support nested
  virtualization for macOS guests (confirmed via Tart's own FAQ and
  `cirruslabs/tart` discussion #701 — a macOS VM cannot itself host
  another hardware-accelerated VM), and OrbStack (which the production
  services depend on for Docker) needs exactly that to run its own Linux
  VM. This isn't a tuning problem, it's a hard platform limitation.
- **One shared instance for all worktrees** would need to switch from
  "up/down per test run" to "always running," and would force either
  serialized test execution or per-run-random usernames colliding across
  concurrent worktree runs. Rejected in favor of true parallelism.

So: each git worktree gets its own docker-compose project (named
`opencloud-e2e-test-<basename of worktree repo root>`, mirroring
`vm-verify`'s own VM-naming convention in `scripts/cleanup-worktree.sh`),
its own dynamically-chosen ports, and its own state directory
(`tests/e2e/.state/`, gitignored, inside the worktree checkout itself —
deleting the worktree deletes this state for free; only the running
containers need explicit teardown, handled by `cmd_teardown` in
`scripts/stack.sh` wired into `scripts/cleanup-worktree.sh`).

## Why Every Access Goes Through a Dedicated Test Caddy

An earlier version of this design skipped Caddy entirely: the browser hit
`http://pocket-id.e2e.local:<port>` directly (a custom hostname mapped to
`127.0.0.1` in `/etc/hosts`, relying on Chromium's WebAuthn secure-context
check accepting any loopback-resolving host, not just literal
`localhost`). That works for a browser on the same machine, but pocket-id
fixes its WebAuthn `RPOrigins` to exactly its configured `APP_URL` at
startup (`RPID: utils.GetHostnameFromURL(deps.AppURL)`, `RPOrigins:
[]string{deps.AppURL}` — verified directly in pocket-id v2.11.0's
`internal/webauthn/service.go`), and the go-webauthn library requires an
*exact* origin match. A remote device on the tailnet necessarily sees a
different origin than a loopback-only one (different IP at minimum), so
there is no way for both "fast local access" and "remote tailnet access"
to independently reach pocket-id on two different origins and have
WebAuthn accept both — discovered in practice when a Caddy-fronted HTTPS
URL for OpenCloud alone (leaving pocket-id on its original loopback
origin) was tried first and hit exactly this mismatch.

The fix: pocket-id (and, for consistency, OpenCloud) is fronted by a
single dedicated per-worktree Caddy process (`start_caddy` in
`scripts/stack.sh`) bound to *both* `127.0.0.1` and the Tailscale IP for
the same vhosts (`<worktree>-pocket-id-test.<hostname>.internal`,
`<worktree>-opencloud-test.<hostname>.internal`) — mirroring production
Caddy's own `default_bind {$TAILSCALE_IP} 127.0.0.1` pattern. `APP_URL`
is set to this Caddy-fronted HTTPS URL from the start, so there is only
ever *one* origin, reachable both ways at once; local Playwright runs and
a human on another tailnet device hit the identical URL. `tls internal`
mints certs from a copy of production's internal CA (see below), so both
paths get an already-trusted cert with no extra client-side trust step.
DNS needs no new configuration: `modules/dnsmasq/darwin.nix`'s
`--address=/.${domain}/$TAILSCALE_IP` is already a wildcard for the whole
`<hostname>.internal` zone, so it resolves the new per-worktree vhosts
too, from this machine and from every other tailnet device — no
`/etc/hosts` editing needed anywhere.

This also solves cross-container reachability. OpenCloud's own compose
service needs to reach pocket-id's OIDC issuer both from the browser and
from inside its own container for server-side token/discovery validation
— and a container's "localhost" is its own loopback, not the host's
(verified empirically: a second container could not reach a
`127.0.0.1:<port>`-published port at all, but could reach it via
`host.docker.internal`). Since the issuer string must match verbatim
between what the browser is redirected to and what the server validates
(`iss` claim), both resolutions need the same hostname:port string
pointing at different IPs. `tests/e2e/fixtures/opencloud.override.yaml`
adds `extra_hosts: <vhost>:host-gateway` entries (Docker's host-gateway
alias, confirmed to reach loopback-bound host ports, which a
Tailscale-IP-bound port is at least as reachable through) to the
OpenCloud container *only* for this e2e stack — layered on top of the
shared `modules/opencloud/compose.yaml` via an extra `-f`, never
modifying that file's behavior for production.

Playwright's browser context sets `ignoreHTTPSErrors: true`
(`playwright.config.ts`) rather than importing the copied CA into a trust
store, since it only needs the ceremony to succeed, not a
warning-free UI.

## Why a Stable, Fixed-Name Test User With a Disposable Passkey

An earlier version of this design created a fresh pocket-id user
(`POST /api/users`) at the start of every run and deleted it at the end
(`DELETE /api/users/:id`), on the theory that a disposable identity
limits what accumulates from an admin API key that pocket-id has no way
to scope down. In practice this broke on the *second* run against the
same worktree: OpenCloud tracks identity by pocket-id's `sub` internally,
but templates its on-disk personal-space directory from the *username*
(`STORAGE_USERS_POSIX_PERSONAL_SPACE_PATH_TEMPLATE`, see
`modules/opencloud/design.md`). Deleting and recreating the pocket-id
user every run gives it a fresh `sub` each time while OpenCloud's own
data intentionally persists across runs (see above) — so after the first
run, OpenCloud was left holding write permissions for a now-deleted
`sub` against a personal-space directory a *new* `sub` with the same
username was trying to reuse, and the "New" button stayed permanently
disabled. Confirmed empirically: a run against a freshly wiped OpenCloud
data directory passed; the very next run, same worktree, failed exactly
this way.

The fix: the pocket-id user (`e2e-test-runner`) is now found-or-created
once and reused indefinitely — `findOrCreateUser` in
`lib/pocket-id-auth.ts` looks it up by username before creating it, so
its `sub` never changes for a given worktree, matching what OpenCloud's
identity model expects. What *is* still replaced every run is just the
passkey credential itself (`clearPasskeys` deletes all of the user's
WebAuthn credentials via `DELETE /api/users/:id/webauthn-credentials/
:credentialId` before registering a fresh one) — this keeps each run's
CDP virtual authenticator (which starts empty in every new browser
process) in sync with what pocket-id has on record, without needing to
export/import private key material across runs.

Registering the passkey itself needs a real WebAuthn *registration*
ceremony (not pocket-id's own test fixtures, which pre-inject an
already-known credential for already-seeded users — not applicable since
our user is freshly created with no credential at all). The only
non-email, non-signup path from "freshly admin-created user" to "browser
session that can register a passkey" is a one-time login-code link
(`POST /api/users/{id}/one-time-access-token`, consumed by navigating to
`/lc/{token}`) — verified against pocket-id v2.11.0's own
`user_controller.go` and its Playwright fixtures
(`account-settings.spec.ts`, `one-time-access-token.spec.ts`).

## Why the Pocket ID Admin Bootstrap Stays Manual (Once Per Worktree)

Pocket ID has no API path to create an admin account or register its
first passkey — by design, matching production
(`modules/pocket-id/design.md`). `scripts/stack.sh`'s `bootstrap_if_needed`
prompts once per worktree for a browser-created admin API key, then
automates everything downstream via that key (group creation, custom
claim, OIDC client registration, allowed-groups). Because Pocket ID's
data directory is a host bind mount that survives `docker compose down`
(only `teardown`/`down -v` removes it), this manual step never repeats
for the same worktree — `up` detects a persisted API key in `tests/e2e/
.env` and skips straight to starting containers.

## Why a Separate Test-Only Caddy Process, Not Production Caddy

Production Caddy's admin API is disabled (`admin off` in
`modules/caddy/darwin.nix`), so there is no cheap way to hand it a new
vhost at runtime — the only way to apply new config is a full daemon
restart, which drops every production vhost (OpenCloud, Immich, Forgejo,
Grafana, Pocket ID) for however long that takes. `scripts/stack.sh`
instead runs its own `caddy run` process per worktree, entirely separate
from the production launchd daemon, started and stopped alongside the
docker containers. It copies (not live-shares) production's internal CA
root cert+key once per worktree so the resulting certificates are already
trusted by any client that already trusts that CA, without two Caddy
processes ever touching the same live PKI storage concurrently.

An SSH-tunnel-only alternative (no new process, no CA copying, browser
reaches a forwarded `localhost` port) was considered for remote access
specifically, but doesn't help here: it would still leave pocket-id's
`APP_URL`/`RPOrigins` pinned to whatever *local* origin the tunnel's
target port uses, and the underlying problem this design solves is that
there must be exactly *one* origin for local and remote access to share
in the first place — an SSH tunnel doesn't create that, a shared Caddy
front door does.

## Why devShell, Not a buildNpmPackage Derivation

This is an occasionally-invoked dev/ops tool, like the existing
`smoke-test-*` skills, not an always-on CLI. `flake.nix`'s `devShells.e2e`
wires `PLAYWRIGHT_BROWSERS_PATH` at a pinned `nixpkgs-playwright` input's
`playwright-driver.browsers` (aarch64-darwin Chromium is a `fetchzip` of
Playwright's own prebuilt tarball there, not a from-source build — see
`pkgs/development/web/playwright/chromium.nix`), avoiding
`@playwright/test`'s own network-downloading postinstall entirely. That
input is pinned independently of the main `nixpkgs` input specifically so
its version can be bumped (kept in lockstep with `package.json`'s
`@playwright/test`, currently both at 1.59.1) without waiting on or
riding along with an unrelated main nixpkgs bump.

## Debugging Note: `/graph/v1beta1/me/drives` Returning Empty

While developing the upload assertion, `GET /graph/v1beta1/me/drives`
repeatedly returned an empty personal-drive list after login — at first
looking like a real OpenCloud provisioning gap for brand-new
auto-provisioned users (corroborating symptoms: the post-login redirect
landing on the general "Spaces > Projects" overview instead of the
personal space, and the "New" upload button staying permanently
disabled). Ruled out along the way:

- **Not a missing NATS backend.** `STORAGE_USERS_ID_CACHE_STORE=
  nats-js-kv` (required for the posix driver) looked at first like it
  needed an external NATS server that `modules/opencloud/compose.yaml`
  never provisions. Checked against OpenCloud's own
  `services/nats/README.md`: `nats-js-kv` is the *embedded, self-contained*
  default registry — no external server needed. This was a dead end.
- **Root cause, confirmed by direct measurement:** repeatedly deleting
  and recreating the pocket-id test user out-of-band via `curl` (done
  manually while debugging, to reset state between experiments) *without*
  also wiping OpenCloud's own data directory left OpenCloud holding
  orphaned internal state tied to a `sub` that no longer existed. A fully
  clean pairing (`stack.sh teardown` + wiping
  `tests/e2e/.state/opencloud/` + a fresh pocket-id user) consistently
  returned the personal drive correctly and immediately, with no retry
  needed. Confirmed by running the actual test suite four consecutive
  times afterward with zero manual intervention between runs — pass
  every time.

In other words, this was never a gap in OpenCloud's provisioning or in
this suite's design — it was an artifact of ad-hoc manual state resets
during debugging that the actual code path (`findOrCreateUser` in
`lib/pocket-id-auth.ts`, which never deletes the pocket-id user) doesn't
do. The lesson generalizes: pocket-id identity and OpenCloud's own data
must be reset *together*, never independently — see "Why a Stable,
Fixed-Name Test User" above for why they're coupled at all.

## Operational Bugs Found Getting `stack.sh` To Be Idempotent

Two more bugs surfaced from actually running `up`/`down`/`teardown`
repeatedly (including back-to-back with no gap) rather than just once:

- `start_caddy` never stopped a previously-running test-caddy process
  before starting a new one, so calling `up` twice without a `down` in
  between (harmless for the docker containers themselves, so an easy
  thing to do) silently orphaned a caddy process every time, each still
  holding its port. Fixed by having `start_caddy` call `stop_caddy`
  first.
- The "is this persisted port taken by something unrelated" check used
  `docker compose ps -q`, which only lists *running* containers. Right
  after `down` (`compose stop`, not `rm`), the containers still exist
  but aren't running, so this misread the check's own just-stopped
  containers as "nothing exists here" and treated their
  not-yet-fully-released host ports as taken by something else. Fixed
  by using `compose ps -a -q` instead. Also split the port-liveness
  check itself (`check_ports_available`) out of the shared env-derivation
  function (`derive_env`) so it only runs from `cmd_up`, not from
  `cmd_down`/`cmd_teardown`, where checking port availability was never
  the point.

## Constraints

- **OpenCloud's own UI selectors in `specs/opencloud.spec.ts` are
  verified against a live instance** — login button, post-login
  account-menu, upload menu ("Files Upload", not "Upload Files"), and
  the "New" button's readiness have all passed repeatedly across many
  runs.
- **Never delete the pocket-id test user out-of-band without also
  wiping `tests/e2e/.state/opencloud/`** — see the debugging note above.
  The test code itself never does this (identity is stable, see "Why a
  Stable, Fixed-Name Test User"), so this only matters if manually
  poking at state while debugging.
- **The CA-copy step needs `sudo`** once per worktree (to read
  `/var/lib/caddy/caddy/pki/authorities/local/`, root-owned) — every
  `stack.sh up` needs this, not just remote access, since it's also how
  the local Caddy front door gets a trusted cert.
- **Every worktree's stack is reachable from the tailnet while its
  containers are running** (not opt-in) — this is a deliberate
  simplification once a Caddy front door was needed anyway for the
  WebAuthn-origin reason above, and is bounded the same way production's
  own exposure is: only while containers are up (torn down after each
  test run), on a per-worktree port that isn't published anywhere, behind
  the same Tailscale ACL policy that already gates every other service on
  this host (`modules/tailscale/policy.hujson`).
- **Persisted ports are not re-picked on every `up`** — only once,
  because Pocket ID's registered OIDC client callback URLs bake in
  OpenCloud's Caddy-fronted URL. If a persisted port is later taken by
  something else, `stack.sh` fails loudly rather than silently re-picking
  (which would desync the registered callback URLs); deleting
  `tests/e2e/.env` forces a full re-bootstrap.
- **Whether a container can reach a Tailscale-IP-bound host port via
  `host-gateway` the same way it reaches a loopback-bound one is inferred
  from the loopback case, not independently verified** — both go through
  the same OrbStack host-routing mechanism, but this is worth confirming
  on first live run.
