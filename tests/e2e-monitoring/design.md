# Monitoring E2E Test Design

## Why This Exists

`smoke-test-monitoring` confirms the containers are running - it says
nothing about whether the actual `prometheus.yml` scrape config is
valid and successfully discovers every configured job, whether Grafana
can actually authenticate and serve a real dashboard, or whether Alloy
is actually shipping logs into Loki. Those are the parts a build
dry-run and a container-status check structurally cannot verify.

## Why Real Scrape Targets, Not Fake Ones

Unlike every other suite in `tests/e2e-*` (which stand up fully
synthetic, isolated data), this one deliberately keeps Prometheus
scraping the _real_ host via `host-gateway` and the _real_
`modules/monitoring/prometheus.yml` (mounted unmodified, same as
production - see `scripts/stack.sh`'s `derive_env`). The alternative -
standing up dummy scrape targets - would only prove Prometheus can
scrape _something_, not that the repo's actual scrape config is
correct. The whole point of this suite is the latter.

A consequence: `activeTargets` health is asserted per-job as
"discovered", never as "healthy" (see `specs/monitoring.spec.ts`'s "実態
に合わせた期待値" comment) - a target like `gitlab-rails` legitimately
reports down when GitLab isn't running on this host, and that's not a
bug in this suite or in `prometheus.yml`. Only `job="prometheus"`
(Prometheus scraping itself, always present regardless of what else is
running) is asserted as actually `up`.

## Why Local Auth, Not OIDC

Same reasoning as `tests/e2e-immich/design.md`: Grafana's
`GF_AUTH_GENERIC_OAUTH_*` config points at Pocket ID in production, but
`fixtures/monitoring.override.yaml` disables it entirely
(`GF_AUTH_GENERIC_OAUTH_ENABLED=false`) for this stack. OIDC/passkey
coverage stays concentrated in `tests/e2e`'s OpenCloud suite; Grafana's
own `GF_SECURITY_ADMIN_USER`/`PASSWORD` env vars already give it a real,
independently-testable local admin account with no external IdP needed.

## Why A Browser Project For An Otherwise API-Only Suite

Four of this suite's five tests use only Playwright's `request` fixture
(same style as `tests/e2e-forgejo`). The fifth logs into Grafana through
the real browser UI and opens a real dashboard, asserting zero
console/page errors during render - this is the one thing an API call
can't verify: that the dashboard JSON itself is well-formed enough for
Grafana's frontend to actually render it, not just that the API returns 200. A dashboard with a broken panel query can still return valid JSON
from `/api/dashboards/uid/...`; it just fails to render.

## Why Isolated, Not the Real Instance

Same reasoning as `tests/e2e-forgejo/design.md`'s "Why Isolated":
`modules/monitoring/compose.yaml` hardcodes host ports (9090, 3200,
3100, 8090) and a fixed `grafana-data` volume name (SQLite - kept as a
named volume rather than a bind mount for the same reason
`tests/e2e/design.md` documents for pocket-id: SQLite crashes under
concurrent access on virtiofs bind mounts). `fixtures/monitoring.override.yaml`
replaces all of these with per-worktree, per-run values via `!override`
so this stack can never collide with (or corrupt) the real one -
`alloy` and `loki` don't need the same treatment: `alloy` has no
published host port at all, and it talks to `loki` purely over the
compose-internal `loki:3100` DNS name, which Docker already scopes per
project.

## What It Does

1. `scripts/stack.sh up` brings up the isolated stack (own ports, own
   Grafana volume, real `prometheus.yml`/`loki-config.yml`/
   `alloy-config.alloy`/Grafana provisioning+dashboards mounted straight
   from `modules/monitoring/`) and waits for Prometheus and Grafana's
   health endpoints.
2. `specs/monitoring.spec.ts` runs five Playwright tests:
   - Confirms every `job_name` in the real `prometheus.yml` (parsed
     directly from the file, not hand-copied into the test, so it can't
     silently drift) has a discovered target in Prometheus's own
     `/api/v1/targets`.
   - Confirms `up{job="prometheus"}` returns `1` via a live PromQL
     query - the one target guaranteed healthy regardless of host state.
   - Logs into Grafana's local admin via `POST /login` and fetches the
     real `services-overview` dashboard via its API, asserting the
     title and that it actually has panels.
   - Logs into Grafana through the real browser UI, opens that same
     dashboard, and asserts zero console/page errors during render.
   - Polls Loki's `/loki/api/v1/query_range` for `{compose_project=~".+"}`
     - Alloy discovers and tails every container on the host (including
       this isolated stack's own containers), so real log lines appear
       without needing to seed anything.
3. `scripts/run.sh` publishes `test-results/html/` (trace: 'on') to
   `modules/static-reports`'s `dataDir/<branch-slug>/monitoring/`, same
   mechanism the other `e2e-test-*` skills use.
4. Tears the stack (containers + volumes + data dirs) all the way down
   every run - Grafana's local admin is recreated fresh from
   `GF_SECURITY_ADMIN_*` env vars every start, so there's no bootstrap
   state worth preserving between runs.

## Known Constraints

- **Depends on real host state for target health** (though never for
  test outcomes) - if the real forgejo/opencloud/immich/gitlab stacks
  aren't running on this host at all, every job except `prometheus`
  itself will report down. This is expected and by design (see "Why
  Real Scrape Targets" above), not a suite bug.
- **`GF_AUTH_GENERIC_OAUTH_ENABLED=false` in the override** means this
  suite can never catch a regression in the actual Pocket ID OIDC wiring
  for Grafana - that's `tests/e2e`'s OpenCloud suite's job for the OIDC
  mechanism generally, not something duplicated per service (see "Why
  Local Auth" above).
- **Grafana's own bundled app-plugin catalog intermittently logs
  "[Plugins] Failed to preload plugin" console errors** for
  `grafana-exploretraces-app`/`grafana-lokiexplore-app`/
  `grafana-pyroscope-app`/`grafana-metricsdrilldown-app` - reproduced
  directly across repeated runs of the same fresh instance (present on
  one run, absent on the next), confirming it's a race in Grafana's own
  plugin-catalog preload unrelated to anything this suite or
  `services-overview.json` configures. `specs/monitoring.spec.ts`
  filters these out by message prefix before asserting on real console
  errors.
