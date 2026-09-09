# Token Usage Design

## Purpose

Give per-chat visibility into Claude Code and opencode token spend, with an
approximate USD cost, without depending on either tool's own dashboard or a
third-party monitoring project.

## Why This Structure

- **Runs as a user LaunchAgent (`launchd.user.agents`), not a root
  daemon.** It only ever reads this user's own `~/.claude/projects` and
  `~/.local/share/opencode/opencode.db`, and pushes over this user's own SSH
  identity - none of that needs root, unlike `modules/monitoring`'s
  node-exporter/textfile-collector daemons, which touch root-owned system
  paths.
- **Claude Code usage is computed from the raw JSONL transcripts**, summed
  per (session, model) from the Anthropic Messages API `usage` block on each
  assistant message, then priced from the static table in `prices.json`.
  Claude Code's transcripts carry no cost field of their own.
- **opencode usage is read from its own SQLite `session` table**, not its
  JSONL-equivalent, because opencode already computes and stores
  `cost`/`tokens_input`/`tokens_output`/etc. per session there (confirmed
  via `.schema session` against a real `opencode.db`). Real spend
  (`session.cost`) is used as-is; recomputing it from raw tokens would just
  reinvent what opencode already gets right.
- **opencode Zen free-tier sessions get a second, `approx="true"` cost
  series** rather than being left at the real $0. Their `model` JSON
  (`providerID: "opencode"`, id suffix `-free`) has real cost 0 by design,
  but the raw token volume is still meaningful to see priced at a
  rough real-world equivalent. Self-hosted local-inference sessions
  (`llamaswap`/`mtplx`/`mlx-server` providers, confirmed present in the same
  table) are left uncosted entirely - they run on the user's own hardware,
  so no market price applies, and pricing them would misrepresent local
  compute as a cloud spend.
- **The Zen free-tier price table is explicitly approximate**, not sourced
  from a live price list (there is no published price for a $0 free tier).
  `prices.json` documents this in its own `_comment` field so the ambiguity
  travels with the data, not just this doc.
- **Anthropic prices came from the `claude-api` skill's cached pricing
  table**, confirmed live for base input/output; cache read/write rates are
  derived from Anthropic's documented cache-pricing ratios (5-minute cache
  write = 1.25x input, cache read = 0.1x input) rather than independently
  sourced per model, except `claude-fable-5-1`'s cache read rate, which the
  skill states directly ($0.25/MTok).
- **Per-chat label cardinality is bounded by a 30-day active window**, not
  by any Prometheus-side relabeling. Both aggregators skip
  sessions/transcripts untouched in the last 30 days before they're even
  parsed (Claude Code: file mtime; opencode: `session.time_updated`), so the
  number of distinct `session` label values in flight at any time roughly
  tracks Prometheus's own 30-day retention (`prometheus.yml`) instead of
  growing without bound as chat history accumulates.
- **Pushed to a remote node-exporter textfile dir over SSH (scp + a remote
  `mv` for atomicity), not queried directly by that host's Prometheus.**
  node-exporter's `--collector.textfile.directory` only reads local files;
  there is no push-metrics endpoint to hit instead. The remote
  `node-exporter-textfile` directory is `chmod 777` (see
  `modules/monitoring/options.nix`) so the unprivileged SSH user can write
  into it, the same trust tradeoff already made for `$MONITORING_DATA_DIR`
  on a single-user, tailnet-only home server.
- **`remoteHost` defaults to nothing and must be set per-host**
  (`services.tokenUsage.remoteHost`), per this repo's no-default-fallbacks
  policy. On `mac-mini-m4-pro` it's set to that same host's own
  `.internal` tailnet name: this machine is simultaneously where the actual
  Claude Code / opencode sessions run (via Herdr worktrees over SSH) and
  where its own monitoring stack lives, so the push is a same-host tailnet
  round-trip today. The mechanism doesn't assume that - a different
  personal machine could point `remoteHost` at either mac-mini's tailnet
  name with no code change.

## Rejected Alternatives

- **A third-party opencode monitoring dashboard/exporter** - rejected;
  reading opencode's own SQLite `session` table directly is simpler than
  standing up another tool, and this repo already has direct-SQLite-read
  precedent (`modules/attic/attic-exporter.py`).
- **Recomputing opencode's cost from raw tokens instead of reading
  `session.cost`** - rejected; opencode already computes this correctly
  (including whatever provider-specific pricing it knows about), so
  recomputing it would only risk disagreeing with the tool's own number.
- **Treating Zen free-tier and self-hosted-model sessions the same way** -
  rejected; only Zen free-tier has a real commercial equivalent worth
  approximating. Self-hosted models have no comparable market price, so
  giving them one would fabricate a number, not approximate one.
- **A price table as a Nix option (`mkOption`) instead of a plain JSON
  file** - rejected; nothing else in the flake needs to override individual
  prices from a host's `darwin.nix`, so an option would add indirection
  with no consumer, and `prices.json` is edited directly like any other
  static config file in this repo (see the top-level File Preference
  Policy).
- **Unbounded historical retention of every chat's cost series** -
  rejected; see the cardinality bullet above.
