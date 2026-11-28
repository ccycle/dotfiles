---
name: dora-metrics
description: Measure this repo's DORA metrics (deployment frequency, lead time, change failure rate, rework rate, time to restore) and the sub-metrics that drive them — blast radius per merged PR and service detection coverage. Use for "DORA metrics", "measure change failure rate", "how many profiles did recent PRs touch", "which services are unmonitored or down", or before and after a refactoring meant to reduce coupling.
---

# DORA Metrics

Why these metrics and how they relate is in [design.md](design.md).

## Requirements

- Run from a checkout of this repo with `origin/main` fetched (`git fetch origin`), on a tailnet device that reaches `forgejo.mac-mini-m4-pro.internal` and `prometheus.<host>.internal`.
- `--comin-log` needs read access to that host's `/var/log/comin.log`, so pass it only on a host running comin.

## Commands

```bash
s=.agents/skills/dora-metrics/scripts/measure.py
$s dora --host mac-mini-m4-pro --host mac-mini-m4 --comin-log /var/log/comin.log
$s detection --host mac-mini-m4-pro --host mac-mini-m4
$s blast-radius --pulls 30
```

`blast-radius` evaluates every profile at each merge commit, about 20 seconds per PR, so run it in the background.
All three print JSON.

## Comparing against a baseline

Earlier runs are kept in [baselines/](baselines/), one directory per date.
Save a new run next to them with the same file names, then compare the two with `jq` before claiming a refactoring helped.
A change that does not move a sub-metric, or moves it without moving its DORA metric, did not help.
