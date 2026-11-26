#!/usr/bin/env bash
set -uo pipefail

hook="$(cd "$(dirname "$0")" && pwd)/block-secret-screen-reads.py"
failures=0

run_hook() {
  jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' | "$hook" >/dev/null 2>&1
}

expect() {
  local want="$1" name="$2" cmd="$3"
  run_hook "$cmd"
  local got=$?
  if [ "$got" = "$want" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected exit $want, got $got"
    failures=$((failures + 1))
  fi
}

incident_typed='herdr pane send-text w1:p2 '\''rbw unlock && EDITOR=vi .agents/skills/credentials-manager/scripts/sops-with-rbw edit modules/forgejo/secrets.yaml'\'''
expect 2 "incident: pre-typing sops-with-rbw edit" "$incident_typed"
expect 2 "sops -d piped to sed" "sops -d modules/forgejo/secrets.yaml | sed -E 's/token.*/<hidden>/'"
expect 2 "sops decrypt subcommand" "sops decrypt --output-type json modules/forgejo/secrets.yaml"
expect 2 "bare sops opens an editor" "EDITOR=vi sops modules/forgejo/secrets.yaml"
expect 2 "sops inside bash -c" "bash -c 'sops -d modules/forgejo/secrets.yaml'"
expect 2 "second line decrypts" $'git status\nsops -d modules/forgejo/secrets.yaml'
expect 0 "sops set via stdin" "printf %s x | jq -Rs . | sops-with-rbw set --value-stdin modules/forgejo/secrets.yaml '[\"k\"]'"
expect 0 "sops updatekeys" "sops updatekeys -y modules/forgejo/secrets.yaml"
expect 0 "grep for the word sops" "git grep -n sops -- modules"
expect 2 "cat rendered nix access tokens" "cat /etc/nix/nix-access-tokens.conf"
expect 2 "masked read of nix access tokens still reads it" "sed -E 's/=.*/<hidden>/' /etc/nix/nix-access-tokens.conf"
expect 2 "read a sops-nix secret" "sudo cat /run/secrets/github_push_mirror_token"
expect 2 "nix config show dumps access-tokens" "nix config show | grep access"
expect 2 "nix config show access-tokens" "nix config show access-tokens"
expect 2 "legacy nix show-config" "nix show-config"
expect 0 "nix config show one other setting" "nix config show substituters"
expect 0 "presence check of rendered secret" "test -s /etc/nix/nix-access-tokens.conf"
expect 0 "ls rendered secret" "ls -l /run/secrets/rendered/nix-access-tokens.conf"
expect 0 "single-key rotation" ".agents/skills/credentials-manager/scripts/secret-rotate.sh --key forgejo_api_token --from-prompt modules/forgejo/secrets.yaml"

if [ "${HERDR_ENV:-}" != 1 ]; then
  echo "skip herdr pane-read cases: HERDR_ENV is not 1"
else
  scratch="$(mktemp -d)"
  age-keygen -o "$scratch/key.txt" 2>/dev/null
  printf 'forgejo_oidc_client_secret: DUMMY-NOT-A-SECRET\n' >"$scratch/secrets.yaml"
  (cd "$scratch" && SOPS_AGE_KEY_FILE=key.txt sops -e -i --age "$(age-keygen -y key.txt)" secrets.yaml) || exit 1

  out=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$scratch" --label hook-test --no-focus)
  tab=$(printf '%s' "$out" | jq -r .result.tab.tab_id)
  pane=$(printf '%s' "$out" | jq -r .result.root_pane.pane_id)
  herdr pane wait-output "$pane" --regex '\S' --timeout 10000 >/dev/null
  herdr pane run "$pane" "SOPS_AGE_KEY_FILE=$scratch/key.txt EDITOR=vi sops edit $scratch/secrets.yaml" >/dev/null
  for _ in $(seq 50); do
    herdr pane process-info --pane "$pane" | jq -e '.result.process_info.foreground_processes[] | select(.argv0 == "sops")' >/dev/null && break
    sleep 0.2
  done

  expect 2 "incident: reading a pane while sops edit runs" "herdr pane read $pane --source visible | grep -v '^~'"
  expect 2 "wait-output on a pane while sops edit runs" "herdr pane wait-output $pane --match x"

  herdr pane send-keys "$pane" escape >/dev/null
  herdr pane send-text "$pane" ':q!' >/dev/null
  herdr pane send-keys "$pane" enter >/dev/null
  for _ in $(seq 50); do
    herdr pane process-info --pane "$pane" | jq -e '.result.process_info.foreground_processes[] | select(.argv0 == "sops")' >/dev/null || break
    sleep 0.2
  done

  expect 0 "reading a pane after sops exited" "herdr pane read $pane --source recent --lines 5"

  herdr tab close "$tab" >/dev/null
  rm -rf "$scratch"
fi

[ "$failures" -eq 0 ] || {
  echo "$failures failure(s)"
  exit 1
}
echo "all passed"
