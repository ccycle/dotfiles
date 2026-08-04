#!/usr/bin/env bash
set -euo pipefail

PAYLOAD=$(cat)

# Already continuing because of a previous stop-hook block: do not re-block,
# or the turn would never end. Claude Code also caps consecutive blocks at 8.
STOP_ACTIVE=$(echo "$PAYLOAD" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty')
LAST_MSG=$(echo "$PAYLOAD" | jq -r '.last_assistant_message // empty')

# Extract the last non-tool user message from the transcript. Fail open if the
# transcript is unreadable or in an unexpected shape.
LAST_USER=$(TRANSCRIPT="$TRANSCRIPT" python3 -c '
import json, os
path = os.environ.get("TRANSCRIPT", "")
last = ""
try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            msg = obj.get("message", {})
            if not isinstance(msg, dict) or msg.get("role") != "user":
                continue
            content = msg.get("content")
            text = ""
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                text = " ".join(
                    p.get("text", "") for p in content
                    if isinstance(p, dict) and p.get("type") == "text"
                )
            if text.strip():
                last = text.strip()
except Exception:
    pass
print(last)
')

# Not an investigation request -> allow. Judge by what the user asked, not the
# answer wording, to avoid blocking ordinary turns that mention keywords.
if ! echo "$LAST_USER" | grep -qiE '調査|調べ|原因|なぜ|investigat|debug|root[ -]?cause|検証|原因究明|トラブル|計測|measure'; then
  exit 0
fi

# Investigation answer that already went through the measure-reviewer -> allow.
if echo "$LAST_MSG" | grep -q 'MEASURE-REVIEW: approved'; then
  exit 0
fi

cat >&2 <<'EOF'
{"decision":"block","reason":"This is an investigation task, but your final answer carries no 'MEASURE-REVIEW: approved' marker. Follow the measure-first skill before finalizing: (1) decompose the question into checkable claims, (2) assign each claim a measurement command and run it, creating the measurement if none exists, (3) draft the answer in claim/evidence/confidence schema, (4) invoke the measure-reviewer subagent via the task tool, (5) fix what it flags, then end your answer with the exact line 'MEASURE-REVIEW: approved'."}
EOF
exit 2
