#!/usr/bin/env bash
set -euo pipefail

PAYLOAD=$(cat)

TOOL_NAME=$(echo "$PAYLOAD" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool_name',''))")
FILE_PATH=$(echo "$PAYLOAD" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool_input',{}).get('file_path',''))")

if [ "$TOOL_NAME" != "Edit" ] && [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

if [[ $FILE_PATH != *.nix ]]; then
  exit 0
fi

cat <<'EOF'
Nix file modified. Run /verify-change before committing to check syntax, linting, and build dry-run.
EOF
