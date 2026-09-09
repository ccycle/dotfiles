# Self-Healing Monitoring Design

## Purpose

Close the gap between "an alert fires" and "someone restarts the right
container": detect firing Prometheus alerts, ask a local LLM what to do
about them, and — once trusted — execute the decision. Reached via a
`grilling`-skill design session; see that session's conclusions for the
full decision tree.

## Why This Structure

- **Detector and executor are a plain shell script; only the judgment step
  is an LLM call.** The script deterministically gathers context (firing
  alerts, scrape-target health, `docker compose ps`, recent Loki errors)
  and deterministically executes whatever action comes back, but does not
  itself decide what "looks broken enough to restart" means — that
  judgment is delegated to the model. This keeps the blast radius of a bad
  LLM response bounded to picking from four fixed actions, never to
  picking an arbitrary command.
- **Local LLM (`llm-server`), not a Claude Code agent.** Chosen explicitly
  over invoking `claude` headless or a scheduled cloud agent: no external
  dependency, no per-invocation cost, and the daemon keeps working if the
  network or an external provider is unavailable. The cost is weaker
  reasoning than a frontier model and the JSON-parsing robustness problem
  addressed below.
- **This module lives under `modules/llm-server/`, not as a top-level
  `modules/self-healing/`.** Package-by-feature places a child under the
  parent it depends on; self-healing's only hard dependency is the local
  LLM API, so it is `modules/llm-server/self-healing/`, imported
  unconditionally by `modules/llm-server/darwin.nix` and gated by its own
  `services.selfHealing.enable`.
- **The Grafana dashboard (`self-healing.json`) lives in
  `modules/monitoring/grafana/dashboards/`, not in this module's own
  directory.** Grafana's dashboard provisioning mounts a single directory
  (`GRAFANA_DASHBOARDS_DIR`, see `modules/monitoring/options.nix` and
  `compose.yaml`) — every other service's dashboard (`immich-health.json`,
  `gitlab-health.json`, ...) already lives there regardless of which
  module owns the service, so this follows that existing precedent rather
  than inventing a second provisioned path.
- **Detection is a fixed daily poll (`StartInterval = 86400`), not
  severity-differentiated.** A deliberate choice to start conservative and
  observe; see Constraints below for the failure mode this accepts.
- **The LLM is queried during `log-only` mode too**, not just once
  `auto-remediate` is on. `log-only` exists specifically so its decisions
  can be reviewed (via the Self-Healing Grafana dashboard) before trusting
  the model to act — a mode that never calls the model would produce
  nothing to review.
- **Judgment and execution are strictly separated**: the LLM's response is
  restricted by prompt instruction to a fixed schema
  (`action`/`target_service`/`reason`) and the script re-validates
  `action` against an allow-list (`restart-service`, `restart-stack`,
  `wait-and-recheck`, `escalate-log-only`) and `target_service`'s project
  against `targetProjects` before doing anything. Any output that doesn't
  parse, or names an action/project outside the allow-list, is coerced to
  `escalate-log-only`. The LLM is never given shell or tool access itself.
- **Out-of-scope alerts (GitLab) are filtered before the LLM is called**,
  by a small `job`/`container_label_com_docker_compose_project` → project
  lookup in the script, not after. This keeps GitLab's alerts from
  spending an LLM call on a decision that can never be acted on anyway.
- **No concurrency lock.** At one poll per day, the probability of two
  runs overlapping is low enough that a lock file would be pure ceremony;
  add one if the poll interval is later shortened.
- **Mode switching (`log-only` → `auto-remediate`) is a manual Nix option
  edit + `darwin-rebuild switch`**, not an automatic graduation after N
  clean days. Automatic promotion would need its own judgment criteria
  layered on top of the same LLM this module is still building trust in.
- **Detection is now primarily an Alertmanager webhook, not the daily
  poll.** `modules/monitoring`'s "no Alertmanager" non-goal is scoped down
  — not lifted — specifically to allow one Alertmanager instance whose
  only receiver is a webhook to `self-healing-webhook`'s local listener
  (see `modules/monitoring/design.md`); no notification channel exists.
  The webhook payload itself is never parsed for alert detail — the daemon
  already re-queries Prometheus's `/api/v1/alerts` for the full current
  firing set on every run, so the webhook only needs to serve as a "poll
  now" wake-up. The daily poll (`launchd.user.agents.self-healing`,
  `StartInterval = 86400`) stays as a backstop for a missed webhook
  delivery, not because a short poll interval is wanted (that's still
  rejected — see Rejected Alternatives).
- **`self-healing` and `self-healing-webhook` are user LaunchAgents
  (`launchd.user.agents`), not root daemons — a change from this module's
  original shape.** The new `propose-fix-pr` action needs this user's own
  opencode config (`~/.config/opencode/opencode.json`, already pointed at
  the local llamaswap provider by `modules/opencode/home.nix`) and git/fj
  credentials for pushing a branch and opening a PR — both only resolve
  correctly in that user's own home directory context, not root's.
  `docker-compose` itself needs no elevated privilege under OrbStack
  (unlike Docker Desktop on Linux), so nothing else was relying on root
  either.
- **`propose-fix-pr` is a fifth allow-listed action**, chosen by the same
  judgment LLM as the other four, for alerts that look structural (a
  config value plausibly wrong) rather than a hung process. Unlike the
  restart actions, its own execution doesn't touch the failing service at
  all — it drafts a change in a separate working copy and opens a PR. Its
  "verification" is human review + CI, not `verify_alert_cleared`, since a
  draft PR by definition hasn't changed anything live yet.
- **`propose-fix-pr` reuses `opencode run --auto` against a local model**
  (`fixModel`, default `llamaswap/qwen/qwen3.6-35b-a3b` — already present
  in this repo's model catalog) to actually draft the change, not the
  small judgment LLM that only ever returns one fixed-schema decision.
  Drafting a real, scoped code change needs genuine coding ability the
  judgment LLM was deliberately never given (see the "no tool-calling"
  bullet below) — this is a second, separate LLM call with a completely
  different job, not an extension of the first one's agentic scope.
- **The guard is a hard, fail-closed changed-file allow-list
  (`fixAllowList`, default empty) plus an unconditional `secrets*.yaml`
  reject, enforced by the script after the fact** — not by restricting
  what opencode is told it may touch in its prompt alone. A prompt
  instruction is not a security boundary; `propose-fix.sh` inspects
  `git diff --name-only` itself and discards (never pushes) any change
  touching a path outside the list. An empty `fixAllowList` disables the
  action outright, so a host must opt in explicitly to what an autonomous
  coding run may modify — same "no default fallback for critical config"
  policy as the rest of this repo.
- **The PR is always opened as a Forgejo draft** (title prefixed `WIP: `,
  Forgejo/Gitea's own draft convention, via `fj pr create`) and this
  script never merges anything — merging still needs a human approval and
  a passing CI run through this repo's normal branch-protection flow
  (already configured on `mac-mini-m4-pro`), unchanged by this feature.
- **A heartbeat metric closes the loop on "did the daemon actually run"**:
  `self-healing-daemon.sh` writes
  `self_healing_last_run_timestamp_seconds` to the node-exporter textfile
  dir on every exit path (via a `trap ... EXIT`), including the early
  "nothing firing" return. `SelfHealingHeartbeatMissing` in
  `prometheus-rules.yml` fires if that timestamp goes stale for ~28h
  (longer than the 24h poll backstop, so a normal poll cycle never trips
  it) — this only ever produces a log line + a Grafana panel, never a
  remediation action, by design (an agent that can't confirm it's alive
  shouldn't also be deciding to restart things).

## Non-Goals

- **GitLab is not a remediation target.** Its failure domain spans
  multiple interdependent subsystems (Rails, Sidekiq, Gitaly, Postgres,
  Redis) with a real restart-ordering dependency that a single
  `restart-service`/`restart-stack` action can't safely express. Revisit
  once a project-specific playbook is worth the complexity.
- **No notification channel.** Same non-goal as `modules/monitoring`:
  reviewing output is a pull (Grafana dashboard, log tail), not a push.
- **No tool-calling / agentic loop for the judgment LLM.** It only ever
  sees one prompt and returns one JSON object; it cannot issue further
  queries. Data gathering is entirely the script's job. `propose-fix-pr`'s
  `opencode run` is a deliberate, separate exception to this for a
  different model with a different job (drafting an actual code change,
  not deciding what to do) — see Why This Structure.
- **No push notification for a proposed fix.** Same as the rest of this
  module: reviewing it is a pull (Forgejo's own PR list/notifications),
  not a push from this daemon.

## Constraints

- **Up to 24h detection latency.** A critical alert firing just after a
  poll waits until the next day's poll to be evaluated. Accepted
  deliberately for this iteration; shorten `StartInterval` (or
  differentiate it by alert `severity`) if this proves too slow in
  practice.
- **Model cold start.** `llm-server` loads a model on first request
  (up to ~1 minute for a large GGUF, see `modules/llm-server/design.md`);
  the LLM call uses a 240s timeout to absorb this.
  Cost the same call pays as with `auto-remediate` mode.
- **Thinking-model output isn't guaranteed to be pure JSON.** The
  configured model (`ornith-ai/Ornith-1.5-35B-A3B-GGUF`) has
  `thinking: true`; its response may include reasoning text before the
  JSON object. The script takes the last `{...}` match in the response
  rather than parsing the whole content as JSON, and treats any parse
  failure as `escalate-log-only`. Not yet verified against the model's
  actual output live — the "unverified as of this writing" caveat pattern
  used elsewhere in this repo's design docs applies here too.
- **`docker-compose` (the Nix-packaged v1 CLI), not `docker compose`.**
  Matches every other launchd-daemon-driven compose invocation in this
  repo (e.g. `modules/monitoring/options.nix`), since the daemon's PATH
  doesn't otherwise include OrbStack's `docker compose` plugin.

## Rejected Alternatives

- **`claude` CLI headless / a scheduled cloud agent as the judgment
  layer** — rejected per explicit preference for a local, self-hosted
  model with no external dependency or per-call cost.
- **Giving the LLM tool-calling / an agentic investigation loop** —
  rejected in favor of the script pre-gathering context and the LLM
  returning one decision, keeping the trust boundary at "the script
  decides what data to show and what commands exist" rather than at
  "the model can query arbitrary APIs."
- **A static alert→action playbook with no LLM** — the original proposal
  from the initial exploration pass; superseded once local-LLM judgment
  was chosen as more adaptable to alert combinations a static table can't
  anticipate, while keeping the same execution-time guardrails.
- **Severity-differentiated polling (critical checked hourly, warning
  daily)** — rejected for this iteration in favor of a single daily
  cadence; the resulting detection-latency gap is recorded above as a
  known, accepted limitation rather than solved.
- **A lock file for concurrent-run prevention** — rejected as unneeded
  ceremony at a one-poll-per-day cadence (see above). Still true once the
  webhook is the primary trigger: Alertmanager's own `group_wait`/
  `group_interval` (30s/5m) already coalesce a burst of alerts into one
  webhook call, and the daily poll only overlaps the webhook path at most
  once a day.
- **Short-interval polling, or a persistent monitoring loop, as the
  detection mechanism instead of Alertmanager** — rejected; see
  `modules/monitoring/design.md`'s equivalent rejection. A webhook only
  fires on an actual state transition, unlike a poll loop that has to
  guess an interval short enough to matter yet cheap enough to run
  constantly.
- **An Alertmanager receiver with a real notification channel** (Slack,
  email, ...) — rejected; the whole point of scoping down the "no
  Alertmanager" non-goal was the firing-webhook use case only, not
  reopening the "no notification channel" non-goal above.
- **Giving `propose-fix.sh` write access without a changed-file
  allow-list, relying on the prompt alone to keep it scoped** — rejected;
  a prompt instruction is not enforcement, see Why This Structure.
- **Auto-merging a passing `propose-fix-pr`** — rejected; CI passing is
  necessary but not sufficient for a change an LLM drafted unsupervised.
  Human review stays mandatory, same bar as every other PR in this repo.

## Constraints (propose-fix-pr)

- **Not yet verified against a real firing alert.** `opencode run --auto`
  succeeding, actually drafting a scoped fix, and `fj pr create` opening a
  draft PR end-to-end has been checked for syntax/allow-list logic only,
  not exercised live — creating a real branch/PR on the production
  Forgejo instance was deliberately not done as part of this
  implementation pass (see the task's own prohibition on touching
  production). Same "unverified as of this writing" caveat pattern as the
  thinking-model-JSON-output note above.
- **`fixAllowList` and `fixRepoUrl`/`fixRepo` are empty by default** — the
  action is inert until a host sets them explicitly.
