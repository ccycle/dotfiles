# Navidrome E2E Test Design

## Why This Exists

`smoke-test-navidrome`（未作成、将来用） would only confirm the container
is running and the health endpoint responds. It says nothing about whether
Navidrome can actually scan a music library, serve tracks via the Subsonic
API, or render its web UI. Those are the parts a build dry-run and a
health check structurally cannot verify, and the parts most likely to
silently break from a compose/storage config change.

## Why No External Auth (ND_EXTAUTH)

Production Navidrome authenticates via Caddy's forward_auth → PocketID
→ `Remote-User` header (ND_EXTAUTH). This isolated E2E stack deliberately
**disables** ND_EXTAUTH because:

- Setting up a real Caddy + PocketID forward_auth chain in the test stack
  would require the full `*.internal` TLS CA, WebAuthn origin, and
  passkey ceremony machinery — the same complexity `tests/e2e`'s OpenCloud
  suite already covers thoroughly.
- Navidrome's own local auth (username/password) is sufficient to exercise
  the core flows this suite targets: library scanning, Subsonic API, and
  web UI rendering.
- The Caddy reverse proxy + forward_auth header forwarding is a
  deployment-layer concern validated by `darwin-rebuild switch` + manual
  browser access on the real instance, not something that needs Playwright
  to verify.

## Why Isolated, Not the Real Instance

Same reasoning as `tests/e2e-immich/design.md`: a herdr worktree checked
out on `mac-mini-m4-pro` shares its Docker daemon with the real
`services.navidrome` instance. Each worktree gets its own docker-compose
project (`navidrome-e2e-test-<worktree>`), its own throwaway host port,
and its own data/music directories under `tests/e2e-navidrome/.state/`.

The `navidrome` container in `modules/navidrome/compose.yaml` binds
`127.0.0.1:4533:4533`. A plain `docker compose -p <other-project>` still
binds that same host port regardless of project name — it would collide
with the real production container. The override in
`fixtures/navidrome.override.yaml` replaces it with a dynamically
assigned port.

## What It Does

1. `scripts/stack.sh up` brings up the isolated Navidrome stack (without
   extauth) and waits for `/health`.
2. `specs/navidrome.spec.ts` runs three Playwright tests:
   - **Web UI loads**: navigates to the web UI and asserts the login form
     is visible (unauthenticated state).
   - **Subsonic API ping**: calls `GET /rest/ping` with no auth and
     asserts a valid Subsonic response (Navidrome returns a success XML
     even without auth for ping).
   - **Music library scan**: places a minimal valid FLAC file in the
     music directory, triggers a scan via the Navidrome API, then asserts
     the Subsonic `getArtists`/`getAlbumList` endpoints return the
     scanned content.
3. `scripts/run.sh` publishes the Playwright HTML report (trace: 'on') to
   `modules/static-reports`'s `dataDir/<branch-slug>/navidrome/`.
4. Tears the stack (containers + volumes + data dirs) down every run.

## Known Constraints

- Docker must be running.
- First run in a given worktree does `npm install` before the suite
  starts.
- The music file fixture is a minimal valid FLAC (generated inline, not
  a real album) — enough for Navidrome's scanner to recognize it as audio
  metadata.
- Without extauth, there's no Caddy forward_auth chain to test. The
  production deployment's auth flow is validated by manual browser access
  after `darwin-rebuild switch`, not by this suite.
