# DORA Metrics Design

## Purpose

The goal is better DORA metrics, not better code metrics.
Each sub-metric is kept only if lowering it is expected to improve a DORA metric, so a refactoring can be judged by whether both moved.

The two problems that motivated this are:

- A change to a tightly coupled part breaks another machine or a running service (change failure rate).
- A broken service goes unnoticed (time to restore, specifically time to detect).

They need different sub-metrics.
Lower coupling reduces the first; no amount of cohesion helps the second, which is a detection and notification gap.

## Metric Tree

| DORA metric                     | Sub-metric                                                           | Lever                                                                  |
| ------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Change failure rate             | Blast radius: profiles whose system derivation changed per merged PR | Decouple shared modules so a change reaches only the hosts it targets  |
| Change failure rate             | Feature directories touched per PR (in the `blast-radius` output)    | Same, measured from the diff instead of evaluation                     |
| Time to restore                 | Endpoints probed / portal endpoints per host                         | Probe every `services.caddy.portalEntries` URL                         |
| Time to restore                 | Alerts firing for more than 24 hours                                 | Route alerts to a human; stop alerting on services a host does not run |
| Deployment frequency, lead time | None yet                                                             | Measured only, since neither is a current pain point                   |

Rework rate (PRs made only of `fix`/`revert` commits) is reported alongside, because it separates fix-only deploys from feature deploys when reading the change failure rate.

## Why These Definitions

- A deployment is a merged PR.
  comin deploys `main` within minutes of a merge (the `merge_to_comin_pickup_hours` output), so the merge time stands in for the deploy time over the long window, where comin's own log does not reach back.
- A failed change is a non-rework PR followed within seven days by a rework PR that shares a conventional-commit scope.
  The repo has no incident records, so this heuristic over-counts unrelated fixes to the same feature and misses failures fixed under another scope.
  Trend matters more than the absolute value.
- Time to restore uses Prometheus `ALERTS` series, which only cover 30 days of retention and only cover what an alert rule watches.
  Before endpoint probes exist, a service that is not scraped can be down with no alert at all, so this number looks better than reality until detection coverage rises.
- Blast radius compares `drvPath`, not file paths, because Nix module merging and `enable` gates decide which hosts a change actually reaches, and only evaluation shows that.
  It cannot see files deployed with `mkOutOfStoreSymlink` (agent rules and skills, herdr, claude, and others): they point into the checkout, so a change to them leaves every `drvPath` unchanged and reaches every machine as soon as its checkout moves, without a build or a comin deploy.
  In the 2026-11-29 baseline, 17 of 30 PRs changed no profile, and most of them touched only such files.

## Rejected Alternatives

- Class cohesion metrics (LCOM and similar) assume classes and methods; the repo is declarative Nix plus shell.
- Line coverage has nothing to execute in Nix module code, and shell coverage would measure the scripts, not the configuration that breaks hosts.
- Co-change counts between feature directories were the first coupling proxy.
  They show correlation between directories, not whether a change reached another host, so they stay a secondary signal.

## Non-Goals

- Metrics are not targets.
  Once a sub-metric is shown to move its DORA metric, it becomes a no-regression check in verify-change, never a number to optimize directly.
