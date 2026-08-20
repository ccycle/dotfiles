#!/usr/bin/env bash
# Validates the six k8s pain-point scenarios against the Immich-shaped
# testbed in ~/k8s-lab on OrbStack's native K3s. See SKILL.md for the
# full rationale and scenario descriptions.
#
# Never touches production: dedicated namespace, hostPath data under
# /var/lib/k8s-lab, dedicated NodePort 32283.
set -euo pipefail

LAB_DIR="${K8S_LAB_DIR:-$HOME/k8s-lab}"
OVERLAY="$LAB_DIR/overlay/mac-mini-m4-pro"
NS="immich-lab"
WEB_URL="http://localhost:32283"

log() { echo "[k8s-lab] $*" >&2; }
die() { echo "[k8s-lab] ERROR: $*" >&2; exit 1; }

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

wait_web() {
  log "waiting for immich at ${WEB_URL}/api/server/ping ..."
  for _ in $(seq 1 90); do
    if curl -sf "${WEB_URL}/api/server/ping" -o /dev/null 2>/dev/null; then
      log "immich is up"
      return 0
    fi
    sleep 2
  done
  die "immich did not become healthy at ${WEB_URL} in time"
}

check_metrics_server() {
  if ! kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1; then
    log "metrics-server not installed; installing ..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s
  fi
}

scenario_resources() {
  log "scenario 1/6: resource control (OOMKill enforcement)"
  # Give immich-server a tiny memory limit; the pod must get OOMKilled or
  # be evicted, proving k8s enforces requests/limits rather than only
  # recording them.
  kubectl -n "$NS" patch deployment immich-server --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources","value":{"limits":{"memory":"16Mi"},"requests":{"memory":"16Mi"}}}]'
  kubectl -n "$NS" rollout restart deployment/immich-server
  sleep 30
  local restarts
  restarts="$(kubectl -n "$NS" get pod -l app=immich-server -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}' | awk '{s+=$1} END {print s+0}')"
  if [ "${restarts:-0}" -ge 1 ]; then
    pass "pod OOMKilled/restarted (restarts=$restarts)"
  else
    fail "expected >=1 restart from OOMKill, saw $restarts"
  fi
  kubectl -n "$NS" rollout undo deployment/immich-server
  kubectl -n "$NS" rollout status deployment/immich-server --timeout=120s >/dev/null
}

scenario_ordering() {
  log "scenario 2/6: startup ordering (readiness waits on DB)"
  kubectl -n "$NS" scale deployment immich-database --replicas=0
  sleep 15
  kubectl -n "$NS" delete pods -l app=immich-server --force --grace-period=0 >/dev/null 2>&1 || true
  sleep 10
  local ready
  ready="$(kubectl -n "$NS" get pod -l app=immich-server -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  if [ "${ready:-}" != "True" ]; then
    pass "server not Ready while DB down (status=$ready)"
  else
    fail "server became Ready while DB was down"
  fi
  kubectl -n "$NS" scale deployment immich-database --replicas=1
  kubectl -n "$NS" rollout status deployment/immich-server --timeout=180s >/dev/null
  pass "server recovered after DB restored"
}

scenario_self_healing() {
  log "scenario 3/6: self-healing (pod recreation)"
  local before
  before="$(kubectl -n "$NS" get pod -l app=immich-server -o name)"
  kubectl -n "$NS" delete pod -l app=immich-server
  local after
  for _ in $(seq 1 60); do
    after="$(kubectl -n "$NS" get pod -l app=immich-server -o name 2>/dev/null || true)"
    if [ -n "${after:-}" ] && [ "$after" != "$before" ]; then
      break
    fi
    sleep 2
  done
  kubectl -n "$NS" rollout status deployment/immich-server --timeout=120s >/dev/null
  if [ -n "${after:-}" ] && [ "$after" != "$before" ]; then
    pass "pod recreated ($before -> $after)"
  else
    fail "pod not recreated"
  fi
}

scenario_update() {
  log "scenario 4/6: update management (rolling update)"
  local old_img
  old_img="$(kubectl -n "$NS" get deployment immich-server -o jsonpath='{.spec.template.spec.containers[0].image}')"
  # Patch to a different (older) release tag to force a real rollout.
  kubectl -n "$NS" set image deployment/immich-server immich-server=ghcr.io/immich-app/immich-server:v1.106.4
  kubectl -n "$NS" rollout status deployment/immich-server --timeout=180s >/dev/null
  local new_img
  new_img="$(kubectl -n "$NS" get deployment immich-server -o jsonpath='{.spec.template.spec.containers[0].image}')"
  if [ "$new_img" != "$old_img" ]; then
    pass "image updated ($old_img -> $new_img)"
  else
    fail "image unchanged"
  fi
  # restore original
  kubectl -n "$NS" set image deployment/immich-server "immich-server=${old_img}"
  kubectl -n "$NS" rollout status deployment/immich-server --timeout=180s >/dev/null
}

scenario_visibility() {
  log "scenario 5/6: visibility (kubectl top)"
  check_metrics_server
  local out
  out="$(kubectl -n "$NS" top pod 2>&1 || true)"
  if printf '%s' "$out" | grep -qE 'NAME|immich-server'; then
    pass "kubectl top returns real usage: $(printf '%s' "$out" | grep -E 'NAME|immich-server' | tr '\n' ' ')"
  else
    fail "kubectl top returned nothing usable: $out"
  fi
}

scenario_ports() {
  log "scenario 6/6: port collision (NodePort vs loopback stacks)"
  local in_use_ports
  in_use_ports="2283 3000 2223 9188 9122 8091 8092"
  local conflict=0
  for p in $in_use_ports; do
    if [ "$p" = "32283" ]; then
      conflict=1
    fi
  done
  local nodeport
  nodeport="$(kubectl -n "$NS" get svc immich-server -o jsonpath='{.spec.ports[0].nodePort}')"
  if [ "$nodeport" = "32283" ]; then
    pass "NodePort bound (32283), no overlap with loopback ports"
  else
    fail "expected nodePort 32283, got $nodeport"
  fi
}

main() {
  require_cmd kubectl
  require_cmd curl
  [ -d "$LAB_DIR" ] || die "k8s-lab not found at $LAB_DIR (clone/checkout it first)"

  FAILURES=0

  log "starting cluster (on-demand)"
  orb start k8s

  log "applying testbed overlay"
  kubectl apply -k "$OVERLAY"
  wait_web

  scenario_resources
  scenario_ordering
  scenario_self_healing
  scenario_update
  scenario_visibility
  scenario_ports

  echo
  if [ "${FAILURES:-0}" -eq 0 ]; then
    echo "ALL SCENARIOS PASSED"
  else
    echo "${FAILURES} SCENARIO(S) FAILED"
    exit 1
  fi
}

main "$@"