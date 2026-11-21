#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
check() {
  local name="$1"
  shift
  if "$@"; then echo "ok   $name"; else
    echo "FAIL $name"
    failures=$((failures + 1))
  fi
}

mkdir -p "$tmp/bin"
cat >"$tmp/bin/herdr" <<'EOF'
#!/bin/sh
case "$1 $2" in
"worktree list") exec cat "$WT_JSON" ;;
"workspace list") exec cat "$WS_JSON" ;;
esac
exit 1
EOF
chmod +x "$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH" XDG_STATE_HOME="$tmp/state" WT_JSON="$tmp/wt.json" WS_JSON="$tmp/ws.json"

wt() {
  local items="" b
  for b in "$@"; do
    case "$b" in ?*:?*) ;; *)
      echo "wt: expected <branch>:<workspace>, got '$b'" >&2
      exit 2
      ;;
    esac
    items="$items,{\"branch\":\"${b%%:*}\",\"is_linked_worktree\":true,\"open_workspace_id\":\"${b#*:}\"}"
  done
  printf '{"result":{"worktrees":[{"branch":"main","is_linked_worktree":false,"open_workspace_id":"w0"}%s]}}' "$items" >"$WT_JSON"
}
cat >"$WS_JSON" <<'EOF'
{"result":{"workspaces":[
 {"workspace_id":"w1","agent_status":"idle"},
 {"workspace_id":"w2","agent_status":"working"},
 {"workspace_id":"w3","agent_status":"blocked"},
 {"workspace_id":"w4","agent_status":"idle"}]}}
EOF

wt a:w1 b:w2 c:w3 d:w4
next=("$here/next.sh")
check "block records dependency" "${next[@]}" block d b
check "block rejects unknown blocker" bash -c '! "$0" block d nope 2>/dev/null' "${next[@]}"
check "block rejects self" bash -c '! "$0" block d d 2>/dev/null' "${next[@]}"

out=$("${next[@]}")
expected='== NEEDS YOU
  c  [blocked]
== READY
  a  [idle]
== RUNNING
  b  [working]
== WAITING
  d  [idle]  <- b'
check "groups in next-action order" test "$out" = "$expected"
check "main checkout is not listed" bash -c '! grep -q main <<<"$0"' "$out"

"${next[@]}" block c b
check "a blocked session outranks its own open blocker" bash -c 'grep -A1 "== NEEDS YOU" <<<"$0" | grep -q "  c  \[blocked\]  <- b"' "$("${next[@]}")"
"${next[@]}" unblock c b

wt a:w1 c:w3 d:w4
check "finished blocker frees the waiter" bash -c 'grep -A2 "== READY" <<<"$0" | grep -q "  d "' "$("${next[@]}")"

wt a:w1 b:w2 c:w3 d:w4
"${next[@]}" unblock d b
check "unblock removes dependency" bash -c '! grep -q WAITING <<<"$0"' "$("${next[@]}")"

[ "$failures" -eq 0 ] && echo "all passed" || {
  echo "$failures failed"
  exit 1
}
