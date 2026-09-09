#!/usr/bin/env bash
# Drafts a fix for a structural alert as a draft Forgejo PR. Invoked by
# self-healing-daemon.sh only for the propose-fix-pr action, and only in
# auto-remediate mode. Guarded by a strict changed-file allow-list: any
# diff touching a path outside FIX_ALLOW_LIST (or any secrets*.yaml file,
# unconditionally) is discarded and nothing is pushed. The resulting PR
# is always a Forgejo draft (title prefixed "WIP: ", Forgejo/Gitea's own
# draft convention) - this script never merges anything; that still needs
# human review and a passing CI run, same as every other PR in this repo.
#
# Env vars (set by darwin.nix): FIX_WORKDIR, FIX_REPO_URL, FIX_REPO,
# FIX_BASE_BRANCH, FIX_ALLOW_LIST (space-separated path prefixes),
# FIX_MODEL.
set -euo pipefail

ALERTNAME="$1"
REASON="$2"
ALERT_JSON_FILE="$3"

TS() { date -u +%FT%TZ; }
log() { echo "$1" | jq -c '. + {component: "self-healing-propose-fix"}'; }

abort() {
  local msg="$1"
  log "$(jq -nc --arg ts "$(TS)" --arg alert "$ALERTNAME" --arg msg "$msg" \
    '{level: "error", ts: $ts, alert: $alert, action: "propose-fix-pr", msg: $msg}')"
  # Discard any staged/unstaged/untracked change opencode made before
  # switching branches back - never leave a rejected diff lying around.
  git -C "$FIX_WORKDIR" reset --hard HEAD >/dev/null 2>&1 || true
  git -C "$FIX_WORKDIR" clean -fd >/dev/null 2>&1 || true
  git -C "$FIX_WORKDIR" checkout "$FIX_BASE_BRANCH" >/dev/null 2>&1 || true
  git -C "$FIX_WORKDIR" branch -D "$BRANCH" >/dev/null 2>&1 || true
  exit 1
}

if [ -z "${FIX_ALLOW_LIST// /}" ]; then
  abort "FIX_ALLOW_LIST is empty - propose-fix-pr is disabled until a host configures it"
fi

BRANCH="self-healing/${ALERTNAME}-$(date +%s)"

if [ ! -d "$FIX_WORKDIR/.git" ]; then
  git clone "$FIX_REPO_URL" "$FIX_WORKDIR"
fi

cd "$FIX_WORKDIR"
git fetch origin "$FIX_BASE_BRANCH"
git checkout -B "$BRANCH" "origin/$FIX_BASE_BRANCH"

PROMPT="A Prometheus alert fired on this homelab and the on-call judgment model
decided the fix needs a config change rather than a container restart.

Alert: ${ALERTNAME}
Reason given: ${REASON}
Alert context: $(cat "$ALERT_JSON_FILE")

Propose the smallest possible fix. Only edit files under one of these
path prefixes: ${FIX_ALLOW_LIST}. Never touch any secrets.yaml or
secrets-*.yaml file. If you cannot identify a safe, scoped fix, make no
changes at all."

if ! opencode run --dir "$FIX_WORKDIR" -m "$FIX_MODEL" --auto "$PROMPT"; then
  abort "opencode run failed"
fi

# `git add -A` before the diff check, not after: `git diff --name-only`
# alone never lists brand-new files (opencode creating a file rather than
# editing one would otherwise slip past this check entirely) - staging
# first and diffing --cached is the only way to see creations too.
git add -A
CHANGED=$(git diff --cached --name-only "origin/$FIX_BASE_BRANCH")
if [ -z "$CHANGED" ]; then
  abort "opencode proposed no changes"
fi

for f in $CHANGED; do
  case "$f" in
  *secrets*.yaml)
    abort "proposed diff touches a secrets file ($f) - discarded"
    ;;
  esac
  in_allow_list=false
  for prefix in $FIX_ALLOW_LIST; do
    case "$f" in
    "$prefix"*) in_allow_list=true ;;
    esac
  done
  if [ "$in_allow_list" != true ]; then
    abort "proposed diff touches a path outside the allow-list ($f) - discarded"
  fi
done
git commit -m "self-healing: proposed fix for ${ALERTNAME}"
git push origin "$BRANCH"

fj pr create "WIP: self-healing: ${ALERTNAME}" \
  --base "$FIX_BASE_BRANCH" --head "$BRANCH" \
  --repo "$FIX_REPO" \
  --body "Automated draft proposed by the self-healing daemon.

Alert: ${ALERTNAME}
Reason: ${REASON}

Never auto-merged: needs human review and a passing CI run."

log "$(jq -nc --arg ts "$(TS)" --arg alert "$ALERTNAME" --arg branch "$BRANCH" \
  '{level: "info", ts: $ts, alert: $alert, action: "propose-fix-pr", msg: "draft PR opened", branch: $branch}')"
