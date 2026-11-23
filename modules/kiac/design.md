# kiac Design

## Purpose

Declare the "homelab" k3s cluster on apple/container and make its recovery after a host reboot observable without logging in to check by hand.

## Why This Structure

- **Recovery is a login-time one-shot agent (`kiac-resume`), not a KeepAlive daemon.**
  kiac and apple/container are per-user tools, and resuming a healthy cluster again in a loop would only add VM churn.
- **Health is observed by a separate periodic agent (`kiac-health`) that only reads.**
  It never remediates; a failed recovery shows up as Prometheus alerts in the `kiac` rule group of [modules/monitoring/prometheus-rules.yml](../monitoring/prometheus-rules.yml) and is fixed by a human.
- **All probes go through `container exec`**, which talks to Apple's runtime over XPC.
  Host binaries not signed by Apple (kubectl, kiac, nix-built tools) get EHOSTUNREACH to the 192.168.64.x vmnet under macOS Local Network privacy, so host-side kubectl or a Prometheus scrape of the node cannot work.
- **Signals are node_exporter textfile metrics**, reusing the monitoring stack's existing collector instead of a new exporter or scrape job.
  The `.prom` files persist across reboots, so "did recovery happen after this boot" is answered by comparing `kiac_resume_end_timestamp_seconds` with `node_boot_time_seconds`, not by the mere presence of a series.
- **Logs live in `/var/log`, not `~/Library/Logs`**, so they fall under the monitoring stack's host-log collection (`/var/log/*.log`) without a kiac-specific collector rule.

## Non-Goals

- No automatic remediation: the self-healing daemon ignores these alerts (no compose project), on purpose.
- No Grafana dashboard: the alert rules plus one PromQL query answer the reboot question.
