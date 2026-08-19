# Forgejo E2E Test Design

## Why This Exists

`modules/forgejo/options.nix`'s CI-runner, branch-protection, and backup
automation (see `modules/forgejo/design.md`) drives the real Forgejo
server binary, the real `forgejo-runner` binary, and the real Forgejo
API - none of which `nix build`/`nix flake check` can exercise, since
those only prove the Nix evaluates and the derivations build. This suite
runs the actual bootstrap logic against a real (isolated) Forgejo
instance and asserts on real outcomes: does the runner actually connect
and execute a job, does branch protection actually reject a force-push,
does a dump file actually land where the backup job expects it.

It exists specifically because this module's design.md already documents
two things that could only be confirmed by running the real commands: the
exact commit-status context format Forgejo Actions reports, and (found
*while building this suite*) that `forgejo-cli` calls must run as
`-u git` or they crash outright as root.

## Why Playwright, With No Browser

The suite is built on `@playwright/test` even though nothing here opens
a browser (unlike `tests/e2e`'s OpenCloud/Pocket-ID suite, which drives a
real passkey login). Two things justified pulling in a browser-testing
framework for a suite with no browser:

- **`request.post`/`request.get`, wrapped in `test.step()`, gets Forgejo's
  REST API calls (repo creation, status polling, branch-protection
  create/read) captured by Playwright's tracer.** With `trace: 'on'` in
  `playwright.config.ts`, every one of those calls - method, URL,
  headers, request/response bodies, timing - is inspectable afterward in
  trace viewer's Network tab, opened directly from the published HTML
  report. That's the concrete win: `status_check_contexts` mismatches or
  a malformed branch-protection payload are visible in the actual
  request/response, not just inferred from a pass/fail line.
- **`docker compose exec` calls (admin bootstrap, runner registration,
  `forgejo dump`) aren't HTTP, so they aren't traced the same way** -
  Playwright's network tracing only sees traffic that goes through its
  own `request`/`page` fixtures. Each such call still runs inside a
  `test.step()` (so it shows in the report's step tree with timing) and
  has its stdout attached via `testInfo.attach()`, but there's no
  request/response waterfall for it - a `child_process.execFileSync`
  call has no such waterfall to record.

Given that split, an earlier version of this suite was plain bash
(`assert()` calls collected into a hand-rolled HTML summary, no traces).
It worked, but "can I see the exact API call" kept being the actual
question worth answering, which is what pushed the API portions
specifically onto Playwright's `request` fixture rather than curl.

## Why Isolated, Not the Real Instance

`modules/forgejo` is deployed on `mac-mini-m4-pro` with real data on the
external drive. A herdr worktree checked out on that same machine shares
its Docker daemon - `docker ps` from inside a worktree can see, and by
default `docker compose -p forgejo ...` would attach to and mutate, the
real running Forgejo container, its SQLite DB, and the real
`ccycle/dotfiles` repo's branch protection. This suite never does that:
`scripts/stack.sh` brings up a second, disposable container under a
project name derived from the worktree directory
(`forgejo-e2e-test-<worktree>`), and `fixtures/forgejo.override.yaml`
repoints both the host ports and the SQLite named volume so the two
stacks cannot collide even if run side by side.

No Caddy front door and no OIDC are needed here (unlike
`tests/e2e/`'s OpenCloud/Pocket-ID suite) - none of the automation under
test authenticates through a browser; it all goes through the Forgejo
API/CLI directly over plain HTTP on a loopback port, so a local admin
user created via `forgejo admin user create` inside the container is
sufficient.

## Two Non-Obvious Fixture Gotchas

- **`ports:` needs the `!override` YAML tag.** Docker Compose merges
  sequences from multiple `-f` files by concatenation, not replacement.
  Without `!override`, the test stack's port list gets *appended* to
  `modules/forgejo/compose.yaml`'s `127.0.0.1:3000`/`127.0.0.1:2223` -
  still binding those, and colliding with the real production container
  the moment it exists. Discovered by running this suite: it errored
  with a real port-in-use failure the first time.

- **`FORGEJO__security__INSTALL_LOCK=true` is required.** Production's
  data volume has this set to `true` only because someone went through
  Forgejo's interactive setup wizard by hand once (see
  `modules/forgejo/design.md` / `docs/oidc-setup.md`); that state then
  persisted in the named volume, not in any committed config. A fresh
  test volume starts with `INSTALL_LOCK=false`, and every state-mutating
  `forgejo`/`forgejo-cli` command fatally refuses to run in that state -
  even though `/api/healthz` already returns 200, since the health
  endpoint doesn't check install-lock. This is additive to the base
  compose file's `environment:` (a key it doesn't already set), so it
  didn't need the same `!override` treatment as `ports:`.

## What It Does

1. `scripts/run.sh` brings up the isolated stack (`scripts/stack.sh up`),
   waits for `/api/healthz`, and exports the compose file paths, state
   dir, and stack env for the spec to pick up.
2. `specs/forgejo.spec.ts` runs as a single Playwright test, its steps in
   order:
   - Creates a local admin user + API token via `forgejo admin user
     create`/`generate-access-token` (`-u git` - see
     `modules/forgejo/design.md` on why exec defaults to root otherwise).
   - Creates a test repo via `request.post` (traced), pushes a minimal
     `.forgejo/workflows/e2e.yaml` (`runs-on: macos-latest`) via `git`.
   - Registers a runner the same way `forgejo-runner-bootstrap` does
     (`forgejo-cli actions generate-secret` + `register`, `forgejo-runner
     generate-config`, `yq` patches the connection in), starts
     `forgejo-runner daemon` as a background child process.
   - Pushes the workflow commit, polls the commit-status API (traced)
     until the runner reports a result, and logs the real context string
     observed - this is the value that must match `branchProtections.*.
     statusCheckContexts` in `modules/mac-mini-m4-pro/darwin.nix`.
   - Applies branch protection via the same API call (traced)
     `forgejo-branch-protection-bootstrap` uses, with the just-observed
     context, then reads it back (traced) and asserts the fields stuck.
   - Confirms a force-push to that now-protected branch is rejected
     (there is no separate "block force push" field - protection alone
     blocks it, see `modules/forgejo/design.md`).
   - Runs the exact `forgejo dump` invocation the backup job uses,
     asserts the file appears on the host side of the bind mount.
   - Tests the retention-pruning one-liner in isolation against seeded
     fake generations (no server involved).
3. `scripts/run.sh` publishes `test-results/html/` (Playwright's own HTML
   reporter, trace.zip included) to `modules/static-reports`'s
   `dataDir/<branch-slug>/forgejo/` - browsable at
   `https://reports.<hostname>.internal/<branch-slug>/forgejo/` once that
   module is applied, same mechanism
   `.agents/skills/e2e-test-opencloud` uses. Keyed by branch rather than
   worktree so the report survives worktree cleanup; the `<service>`
   subdirectory keeps this suite from clobbering another suite's report
   for the same branch. Each run also prunes any service dir untouched
   for 14+ days (and the branch dir once it's empty). Best-effort: a
   worktree on a host without that module enabled doesn't fail the run
   over it.
4. Tears the container and its volume down (`scripts/stack.sh teardown`),
   so every run starts from a clean instance. Unlike `tests/e2e`'s
   OpenCloud suite, nothing here needs an expensive one-time manual
   bootstrap worth preserving between runs - leftover state would
   instead just make the next run's `admin user create` fail on a
   duplicate user.

## Known Constraints

- Docker must be running, and the daemon must be the same one
  `modules/forgejo` deploys against (true for any worktree checked out
  on the machine that runs it) - the isolation described above is what
  makes that safe.
- `nix shell nixpkgs#forgejo-runner`/`nixpkgs#yq-go` are used directly
  from the spec rather than via this flake's pinned inputs, since the
  suite only needs *a* working binary, not the exact pinned version -
  keeps the suite runnable without a full flake evaluation first. This is
  a version-drift risk in principle (the registry's `nixpkgs` isn't this
  repo's pinned input) but hasn't caused an issue in practice, since
  neither binary's CLI surface used here is version-sensitive.
- `npx playwright test` runs inside `nix develop <repo>#e2e` (the same
  devshell `tests/e2e` uses) for Node + the pre-fetched Playwright
  Chromium bundle - unused here (no browser project is configured), but
  reusing the existing shell avoided adding a second one just for Node.
