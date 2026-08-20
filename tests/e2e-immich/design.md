# Immich E2E Test Design

## Why This Exists

`smoke-test-immich` confirms the container is running and the health
endpoint responds - it says nothing about whether a photo uploaded
through the actual UI reaches the host filesystem, or whether Immich's
background jobs actually generate a thumbnail for it. Those are the
parts a build dry-run and a health check structurally cannot verify, and
the parts most likely to silently break from a storage/compose config
change (see `modules/immich/compose.yaml`'s upload volume mount).

## Why Local Auth, Not OIDC/Passkey

`modules/immich/compose.yaml` configures Pocket ID as an OIDC provider
alongside local auth - both are available in production. This suite
deliberately exercises only local auth
(`POST /api/auth/admin-sign-up` / `POST /api/auth/login`), leaving
OIDC/passkey coverage concentrated in `tests/e2e`'s OpenCloud suite:

- The passkey/WebAuthn ceremony, pocket-id session handling, and OIDC
  consent-screen edge cases are already exercised thoroughly there (see
  `tests/e2e/design.md`) - duplicating that machinery per service buys
  nothing new, only more surface area to keep in sync with pocket-id
  changes.
- Immich's own admin bootstrap (`admin-sign-up`) requires no external
  IdP at all, unlike OpenCloud's auto-provisioned OIDC users - it's the
  simpler, more direct path to a working authenticated session.
- The isolated stack skips the dedicated test-Caddy + WebAuthn-origin
  machinery `tests/e2e/scripts/stack.sh` needs for pocket-id entirely -
  local auth over plain HTTP on a loopback port is enough.

## Why Isolated, Not the Real Instance

Same reasoning as `tests/e2e-forgejo/design.md`'s "Why Isolated": a
herdr worktree checked out on `mac-mini-m4-pro` shares its Docker daemon
with the real `services.immich` instance. Each worktree gets its own
docker-compose project (`immich-e2e-test-<worktree>`), its own throwaway
host ports (found dynamically, persisted per-worktree in `.env`), and its
own upload/db directories under `tests/e2e-immich/.state/` - never
`services.immich.uploadDir`/`dbDir`.

The `model_cache` named volume and the `immich-machine-learning`/`redis`/
`database` services carry no explicit `name:` in
`modules/immich/compose.yaml`, so Docker Compose already namespaces them
by project name - only the services that hardcode host ports
(`immich-server`, `postgres-exporter`, `redis-exporter`) need the
`!override` treatment in `fixtures/immich.override.yaml` (see that
file's own comment for why `!override` specifically, not plain
concatenation).

## What It Does

1. `scripts/stack.sh up` brings up the isolated stack and waits for
   `/api/server/ping`.
2. `specs/immich.spec.ts` runs two Playwright tests in order
   (`workers: 1`, so declaration order is deterministic):
   - Signs up the first admin via the API, logs in through the real
     browser UI, and asserts the authenticated app is reached (handling
     whatever one-time redirect a brand-new admin can land on -
     `/auth/change-password`, `/auth/onboarding` - along the way).
   - Logs in again (the same stable admin from the first test - the
     `admin-sign-up` endpoint only ever succeeds once per fresh
     database), uploads a real minimal JPEG through the UI's file
     chooser, then confirms via `POST /api/search/metadata` (not by
     guessing Immich's internal `upload/library/<userId>/...` layout)
     both that the asset's `originalPath` maps to a real file under the
     host `IMMICH_UPLOAD_DIR`, and that its `thumbhash` becomes
     non-null within a short poll window - the actual thumbnail-job
     completing, not just the upload finishing.
3. `scripts/run.sh` publishes `test-results/html/` (trace: 'on') to
   `modules/static-reports`'s `dataDir/<branch-slug>/immich/`, same
   mechanism `e2e-test-forgejo`/`e2e-test-opencloud` use.
4. Tears the stack (containers + volumes + data dirs) all the way down
   every run - unlike `tests/e2e`'s OpenCloud suite, nothing here needs
   an expensive one-time manual bootstrap worth preserving between runs,
   and `admin-sign-up` can only ever succeed against a fresh database
   anyway, so persisting state would only make the next run fail.

## Known Constraints

- **Immich's `POST /api/auth/admin-sign-up` only succeeds once per
  database** (`@Authenticated({ setup: true })` in its own controller) -
  this suite relies on that by tearing the whole stack down every run,
  never by tracking whether an admin already exists.
- **The uploaded file must be a real, valid JPEG**, not a renamed text
  file - Immich's upload pipeline validates file content, and a fixture
  that isn't a real image would fail before ever reaching the
  thumbnail-generation step this suite means to test.
- **Immich renders two "Upload" buttons simultaneously** (desktop text
  button + mobile icon button, `NavigationBar.svelte`) - the spec
  deliberately clicks the empty-timeline's own
  "Click to upload your first photo" button instead of either navbar
  one, sidestepping the ambiguity rather than disambiguating it (same
  category of issue `tests/e2e/lib/pocket-id-auth.ts` documents for
  pocket-id's own "Add Passkey" button, different fix).
- **A "new version available" nag dialog appears on first page load**
  (onboarding and the first `/photos` visit both hit it) whenever the
  pinned image version is behind Immich's latest release, and blocks
  every other interaction - including file uploads - until dismissed.
  Not asserted as always-present (a pinned version catching up to
  latest would make it stop appearing), just dismissed if seen.
- **The timeline's empty-state placeholder does not disappear on its own
  after a successful upload** in this isolated stack - confirmed via
  trace network inspection that `POST /api/assets` still returns `201`
  and the asset is fully processed, the UI just doesn't reactively
  re-render the empty state away without a reload/websocket update this
  suite doesn't rely on. The spec waits on the actual upload API
  response, never a UI-level "did the placeholder go away" signal.
