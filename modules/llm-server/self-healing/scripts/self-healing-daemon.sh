#!/usr/bin/env bash
# Detector + executor for self-healing monitoring. The Nix wrapper (darwin.nix)
# sets PATH and the env vars this script reads: PROMETHEUS_URL, LOKI_URL,
# LLM_SERVER_URL, MODEL_ID, SELF_HEALING_MODE, TARGET_PROJECTS.
set -euo pipefail

TS() { date -u +%FT%TZ; }

log() {
  # One-JSON-object-per-line, printed to stdout (captured by launchd into
  # /var/log/self-healing.log — see the Alloy JSON-extraction stage in
  # modules/monitoring/alloy-config.alloy, which already tolerates
  # non-JSON lines interleaved in the same file). `component` is stamped
  # here in one place so every emitted line is filterable in Loki even
  # though `source="host"` alone doesn't distinguish this file from other
  # host logs.
  echo "$1" | jq -c '. + {component: "self-healing"}'
}

is_in_scope_project() {
  local project="$1"
  for p in $TARGET_PROJECTS; do
    [ "$p" = "$project" ] && return 0
  done
  return 1
}

# Prometheus job name -> docker compose project. Mirrors the "Metrics job
# map" table in .agents/skills/investigate-service/SKILL.md; kept here only
# as the minimal lookup needed to pre-filter alerts before spending an LLM
# call, not as a duplicate of that skill's full triage knowledge.
job_to_project() {
  case "$1" in
    gitlab-*) echo "gitlab" ;;
    immich-*) echo "immich" ;;
    opencloud) echo "opencloud" ;;
    forgejo) echo "forgejo" ;;
    prometheus | cadvisor) echo "monitoring" ;;
    *) echo "" ;;
  esac
}

alert_project() {
  # ContainerRestarting carries the compose project directly; every other
  # rule is looked up by its Prometheus job label.
  local alert="$1"
  local from_label
  from_label=$(echo "$alert" | jq -r '.labels.container_label_com_docker_compose_project // empty')
  if [ -n "$from_label" ]; then
    echo "$from_label"
    return
  fi
  job_to_project "$(echo "$alert" | jq -r '.labels.job // empty')"
}

build_prompt() {
  local alert="$1"
  cat <<PROMPT
You are a remediation-decision assistant for a self-hosted homelab. Choose
exactly one action for the alert below. Respond with a single JSON object
and nothing else, matching this schema:

{"action": "restart-service" | "restart-stack" | "wait-and-recheck" | "escalate-log-only",
 "target_service": "<compose-project>/<service-name>" (restart-service),
                    "<compose-project>" (restart-stack), or "" otherwise,
 "reason": "<one sentence>"}

Rules:
- Choose restart-service when a single container looks stuck/crashed and
  the failure is isolated to it.
- Choose restart-stack when multiple interdependent containers in the same
  project look affected, or the failure mode is unclear which container is
  root cause.
- Choose wait-and-recheck for a failure that looks transient (e.g. a brief
  error-rate blip) and doesn't yet warrant action.
- Choose escalate-log-only if unsure, or the failure looks structural
  (data corruption, misconfiguration, disk full) rather than a hung
  process — restarting will not help.
- <compose-project> in target_service MUST be exactly one of: $TARGET_PROJECTS

Alert:
$alert

Current down scrape targets:
$DOWN_TARGETS

Container status for in-scope projects:
$PROJECT_STATUS

Recent error/fatal log lines (last 15m) for in-scope projects:
$RECENT_ERRORS
PROMPT
}

ask_llm() {
  local prompt="$1"
  curl -sf --max-time 240 "$LLM_SERVER_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "$MODEL_ID" --arg prompt "$prompt" \
      '{model: $model, temperature: 0, messages: [{role: "user", content: $prompt}]}')"
}

verify_alert_cleared() {
  local alertname="$1"
  sleep 60
  curl -sf "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=ALERTS{alertname=\"$alertname\"}" \
    | jq -e '.data.result | length == 0' >/dev/null 2>&1
}

execute_action() {
  local action="$1" target="$2"
  local project="${target%%/*}"
  case "$action" in
    restart-service)
      local service="${target#*/}"
      docker-compose -p "$project" restart "$service"
      ;;
    restart-stack)
      docker-compose -p "$project" restart
      ;;
  esac
}

# --- Gather alerts ---
ALERTS_JSON=$(curl -sf "$PROMETHEUS_URL/api/v1/alerts" 2>/dev/null || echo '{"data":{"alerts":[]}}')
FIRING=$(echo "$ALERTS_JSON" | jq -c '[.data.alerts[] | select(.state == "firing")]')

if [ "$(echo "$FIRING" | jq 'length')" -eq 0 ]; then
  log "$(jq -nc --arg ts "$(TS)" '{level: "info", ts: $ts, msg: "no firing alerts"}')"
  exit 0
fi

# Split into in-scope / out-of-scope up front so out-of-scope alerts (e.g.
# GitLab) never trigger an LLM call.
IN_SCOPE="[]"
while IFS= read -r alert; do
  project=$(alert_project "$alert")
  alertname=$(echo "$alert" | jq -r '.labels.alertname')
  if [ -n "$project" ] && is_in_scope_project "$project"; then
    IN_SCOPE=$(echo "$IN_SCOPE" | jq -c --argjson a "$alert" '. + [$a]')
  else
    log "$(jq -nc --arg ts "$(TS)" --arg alert "$alertname" --arg project "$project" \
      '{level: "info", ts: $ts, alert: $alert, action: "skipped-out-of-scope", target_service: $project}')"
  fi
done < <(echo "$FIRING" | jq -c '.[]')

if [ "$(echo "$IN_SCOPE" | jq 'length')" -eq 0 ]; then
  exit 0
fi

# --- Shared context (computed once, reused for every in-scope alert) ---
DOWN_TARGETS=$(curl -sf "$PROMETHEUS_URL/api/v1/targets" 2>/dev/null \
  | jq -c '[.data.activeTargets[] | select(.health != "up") | {job: .labels.job, health, lastError}]')

PROJECT_STATUS=""
for project in $TARGET_PROJECTS; do
  status=$(docker-compose -p "$project" ps --format json 2>/dev/null || echo "")
  PROJECT_STATUS="${PROJECT_STATUS}${project}: ${status}
"
done

RECENT_ERRORS=$(curl -sG "$LOKI_URL/loki/api/v1/query_range" \
  --data-urlencode "query={compose_project=~\"$(echo "$TARGET_PROJECTS" | tr ' ' '|')\"} |~ \"(?i)(error|fatal|panic)\"" \
  --data-urlencode "since=15m" --data-urlencode "limit=50" 2>/dev/null \
  | jq -r '.data.result[].values[][1]' 2>/dev/null || echo "")

# --- Per-alert decision + (optional) execution ---
while IFS= read -r alert; do
  alertname=$(echo "$alert" | jq -r '.labels.alertname')
  prompt=$(build_prompt "$alert")

  response=$(ask_llm "$prompt") || {
    log "$(jq -nc --arg ts "$(TS)" --arg alert "$alertname" \
      '{level: "error", ts: $ts, alert: $alert, action: "escalate-log-only", reason: "llm-server unreachable"}')"
    continue
  }

  raw_content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
  # The model may prefix reasoning/thinking text; take the last {...} object.
  decision=$(echo "$raw_content" | grep -o '{[^{}]*}' | tail -n1 || true)

  action=$(echo "$decision" | jq -r '.action // empty' 2>/dev/null || true)
  target=$(echo "$decision" | jq -r '.target_service // empty' 2>/dev/null || true)
  reason=$(echo "$decision" | jq -r '.reason // empty' 2>/dev/null || true)

  case "$action" in
    restart-service | restart-stack | wait-and-recheck | escalate-log-only) ;;
    *)
      action="escalate-log-only"
      reason="unparseable or invalid LLM output"
      ;;
  esac

  if [ "$action" = "restart-service" ] || [ "$action" = "restart-stack" ]; then
    if ! is_in_scope_project "${target%%/*}"; then
      action="escalate-log-only"
      reason="target project '${target%%/*}' is not in TARGET_PROJECTS"
    fi
  fi

  executed=false
  verified=""
  if [ "$SELF_HEALING_MODE" = "auto-remediate" ] && { [ "$action" = "restart-service" ] || [ "$action" = "restart-stack" ]; }; then
    if execute_action "$action" "$target"; then
      executed=true
      if verify_alert_cleared "$alertname"; then
        verified=true
      else
        verified=false
      fi
    fi
  fi

  log "$(jq -nc \
    --arg ts "$(TS)" \
    --arg alert "$alertname" \
    --arg action "$action" \
    --arg target "$target" \
    --arg reason "$reason" \
    --arg mode "$SELF_HEALING_MODE" \
    --argjson executed "$executed" \
    --arg verified "$verified" \
    --arg prompt "$prompt" \
    --arg llm_output "$raw_content" \
    '{level: (if $verified == "false" then "warn" else "info" end),
      ts: $ts, alert: $alert, action: $action, target_service: $target,
      reason: $reason, mode: $mode, executed: $executed,
      verified: (if $verified == "" then null else ($verified == "true") end),
      prompt: $prompt, llm_output: $llm_output}')"
done < <(echo "$IN_SCOPE" | jq -c '.[]')
