#!/usr/bin/env bash
set -euo pipefail

PAYLOAD=$(cat)

TOOL_NAME=$(echo "$PAYLOAD" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool_name',''))")
FILE_PATH=$(echo "$PAYLOAD" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool_input',{}).get('file_path',''))")

if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

PROTECTED_FILES="flake.lock secrets.yaml secrets.json"

for f in $PROTECTED_FILES; do
  if [ "$BASENAME" = "$f" ]; then
    echo '{"decision": "block", "reason": "'"$BASENAME"' is a manually-managed file. Do not edit it directly. Use the appropriate tool (nix flake update, sops, etc.) instead."}' >&2
    exit 2
  fi
done
