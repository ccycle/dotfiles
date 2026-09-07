---
name: investigate-forgejo-ci
description: Investigate a failing CI run on a Forgejo pull request in this repo (forgejo.mac-mini-m4-pro.internal/ccycle/dotfiles) using fj and the Forgejo API. Use when a PR's CI is red and the cause is unknown.
---

# Investigate Forgejo CI

Root-cause a failing `Syntax + Structure + Build` or `Formatter` CI job on a
Forgejo PR for this repo, without asking the user to open a browser.

## `fj` gotchas (learned the hard way)

- **`-R`/`-r` must come right after the top-level subcommand, before the
  action.** `fj pr -R origin status 17` works; `fj pr status -R origin 17`
  does not (`unexpected argument '-R'`).
- **`fj pr status` and `fj pr view` sometimes crash** with `Error: the
  response from forgejo was not properly structured` when a job's log URL
  field can't be parsed as a relative URL. Don't retry these — fall back to
  `fj actions tasks` (below), which is unaffected.
- **`fj actions tasks` has no log-viewing subcommand.** Listing tasks only
  gives status/duration, not the failure detail — you still need the API
  call in the next section for the actual error.

## Workflow

1. **Identify the PR and its head commit**

   ```bash
   fj pr -R origin view <PR_NUMBER>
   ```

2. **Find the failing job**

   ```bash
   fj actions -R origin tasks
   ```

   Match the row whose commit prefix is the PR's head commit and whose
   trigger is `(push)` or `(pull_request)`. The leading `#N` is the job id;
   the status column shows `failure`.

3. **Fetch the full job log**

   The Forgejo job-logs endpoint is readable with an unauthenticated GET on
   this instance — no need to read the token out of
   `~/Library/Application Support/Cyborus.forgejo-cli/keys.json` for a
   read-only investigation:

   ```bash
   curl -s "https://forgejo.mac-mini-m4-pro.internal/api/v1/repos/ccycle/dotfiles/actions/jobs/<job_id>/logs" \
     -o /tmp/job.log
   ```

4. **Grep for the actual error**, not just any line containing "error" (Nix
   logs are noisy — package names like `errore`, `thiserror` match too):

   ```bash
   grep -nE '^[0-9TZ:.+-]+ error:|hash mismatch|Cannot build|panic:|FAIL' /tmp/job.log | tail -40
   ```

   Common Nix CI failure signature in this repo: `hash mismatch in
   fixed-output derivation '<drv>': specified: <old-hash> got: <new-hash>`.
   This means a flake input that a `drv.nix` vendors (e.g. `vendorHash` /
   `npmDepsHash` / `cargoHash`) moved without the corresponding derivation's
   pinned hash being updated — grep the repo for the `specified` hash to find
   which `drv.nix` owns it, and update it to the `got` value.

5. **Verify the fix locally before pushing** — build the specific output
   (e.g. `nix build '.#gcx'` if `flake.nix` exposes it under `packages`),
   not the whole system closure, to keep the loop fast.

6. **Push and re-check** — after pushing, CI takes several minutes; use
   `ScheduleWakeup` to check back rather than a `sleep`-polling loop.

## Reference

- Repo: `ccycle/dotfiles`, remote name `origin`.
- Forgejo API base: `https://forgejo.mac-mini-m4-pro.internal/api/v1/repos/ccycle/dotfiles`.
- `fj actions` has no `secrets`/`variables` read needed for this workflow —
  only `tasks`.
