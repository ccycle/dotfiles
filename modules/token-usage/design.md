# Token Usage Design

## Purpose

Give per-chat visibility into Claude Code and opencode token spend, with an
approximate USD cost, without depending on either tool's own dashboard or a
third-party monitoring project.

## Why This Structure

- **Runs as a user LaunchAgent (`launchd.user.agents`), not a root
  daemon.** It only ever reads this user's own `~/.claude/projects` and
  `~/.local/share/opencode/opencode.db`, and writes into a world-writable
  textfile dir - none of that needs root, unlike `modules/monitoring`'s
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
  (`ollama`/`llamaswap`/`mtplx`/`mlx-server` providers; `llamaswap` and the others were confirmed present in the same
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
- **Written straight into this host's node-exporter textfile dir, on the host that runs the monitoring stack.**
  node-exporter's `--collector.textfile.directory` only reads local files, and the sessions and the stack live on the same machine (`mac-mini-m4-pro`).
  The directory is `chmod 777` (see [modules/monitoring/options.nix](../monitoring/options.nix)) so this unprivileged agent can write into it, the same trust tradeoff already made for `$MONITORING_DATA_DIR` on a single-user, tailnet-only home server.

## Rejected Alternatives

- **Pushing the `.prom` file over SSH (scp to `remoteHost`)** - the original design, removed on 2026-11-28.
  It never delivered a sample: the Nix `openssh` rejected the Apple-only `UseKeychain` line in `~/.ssh/config`, and this host has no `authorized_keys` for a same-host login anyway, while the script exited 0 so launchd showed success.
  Revisit only when a second machine with its own sessions needs to report; at that point make the remote target explicit and its auth tested.
- **A third-party opencode monitoring dashboard/exporter** - rejected;
  reading opencode's own SQLite `session` table directly is simpler than
  standing up another tool, and this repo already has direct-SQLite-read
  precedent ([modules/attic/attic-exporter.py](../attic/attic-exporter.py)).
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
