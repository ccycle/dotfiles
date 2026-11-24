#!/usr/bin/env bash
# Integration test for check-citations against a real local HTTP server.
# Serves local fixture files only, so it needs no network.
# Usage: check-citations.test.sh
set -uo pipefail

checker="$(cd "$(dirname "$0")" && pwd)/check-citations"
work="$(mktemp -d)"
failures=0
trap 'kill "$server_pid" 2>/dev/null; rm -rf "$work"' EXIT

mkdir "$work/site"
cat >"$work/site/page.html" <<'EOF'
<html><head><script>var hidden = "script text is not page text";</script></head>
<body><p>Firefox <b>sup</b>ports Text Fragments since version 131.</p>
<p>日本語の　本文も 照合できる。</p><p>A built-in fallback, then more.</p></body></html>
EOF
printf 'line one\nline two\nline three\n' >"$work/notes.txt"

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work/site" >/dev/null 2>&1 &
server_pid=$!
for _ in $(seq 50); do
  curl -sf "http://127.0.0.1:$port/page.html" >/dev/null && break
  sleep 0.1
done
page="http://127.0.0.1:$port/page.html"

# expect <name> <expected-exit> <report-body>
expect() {
  local name="$1" expected="$2"
  printf '%s\n' "$3" >"$work/report.md"
  "$checker" check "$work/report.md" >"$work/out" 2>&1
  local actual=$?
  if [ "$actual" = "$expected" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected exit $expected, got $actual"
    sed 's/^/     /' "$work/out"
    failures=$((failures + 1))
  fi
}

expect "quote on page passes" 0 \
  "- Firefox supports it [\"supports Text Fragments\"]($page#:~:text=supports%20Text%20Fragments)"
expect "start,end range passes" 0 \
  "- Since 131 [q]($page#:~:text=Firefox,version%20131)"
expect "prefix and suffix are accepted" 0 \
  "- Since 131 [q]($page#:~:text=Firefox-,supports,-Text)"
expect "CJK with odd whitespace passes" 0 \
  "- Japanese [q]($page#:~:text=%E6%97%A5%E6%9C%AC%E8%AA%9E%E3%81%AE%E6%9C%AC%E6%96%87)"
expect "fabricated quote fails" 1 \
  "- Firefox supports it [q]($page#:~:text=since%20version%20120)"
expect "end before start fails" 1 \
  "- Range [q]($page#:~:text=version%20131,Firefox)"
expect "script content is not page text" 1 \
  "- Hidden [q]($page#:~:text=script%20text%20is%20not)"
expect "bare URL without fragment fails" 1 \
  "- Firefox supports it [q]($page)"
expect "claim without citation fails" 1 \
  "- Firefox supports it"
expect "unreachable page fails" 1 \
  "- Gone [q](http://127.0.0.1:$port/missing.html#:~:text=Firefox)"
expect "unverifiable marker passes" 0 \
  "- Nobody documents this [unverifiable] (page needs login)"
expect "file line in range passes" 0 \
  "- Notes [notes.txt](notes.txt#L2-L3)"
expect "file line out of range fails" 1 \
  "- Notes [notes.txt](notes.txt#L4)"
expect "one bad citation fails the whole claim" 1 \
  "- Both [a]($page#:~:text=Firefox) [b]($page#:~:text=Chrome)"
expect "nested lines belong to the claim" 0 \
  "- Firefox supports it
  - evidence: [q]($page#:~:text=Firefox)"
expect "footnote citation passes" 0 \
  "- Firefox supports it.[^1]

[^1]: [“Firefox … version 131”]($page#:~:text=Firefox,version%20131) (page)"
expect "footnote with a broken quote fails" 1 \
  "- Firefox supports it.[^1]

[^1]: [“since version 120”]($page#:~:text=since%20version%20120) (page)"
expect "blank lines between footnotes pass" 0 \
  "- Firefox supports it.[^1] Since 131.[^2]

[^1]: [a]($page#:~:text=Firefox)

[^2]: [b]($page#:~:text=version%20131)"
expect "undefined footnote fails" 1 \
  "- Firefox supports it.[^1]"
expect "footnote without a link fails" 1 \
  "- Firefox supports it.[^1]

[^1]: the page says so"
expect "footnote continuation line is checked" 1 \
  "- Firefox supports it.[^1]

[^1]: [a]($page#:~:text=Firefox)
    [b]($page#:~:text=Chrome)"
expect "report with no claims fails" 1 \
  "Just prose, no list."

# link subcommand: encodes the quote and refuses text not on the page.
link_out="$("$checker" link "$page" "supports Text Fragments" 2>/dev/null)"
if [ "$link_out" = "$page#:~:text=supports%20Text%20Fragments" ]; then
  echo "ok   link builds an encoded fragment"
else
  echo "FAIL link output: [$link_out]"
  failures=$((failures + 1))
fi
dash_out="$("$checker" link "$page" "A built-in fallback, then" 2>/dev/null)"
if [ "$dash_out" = "$page#:~:text=A%20built%2Din%20fallback%2C%20then" ]; then
  echo "ok   link encodes dash and comma"
else
  echo "FAIL link dash/comma output: [$dash_out]"
  failures=$((failures + 1))
fi
# The encoded link must round-trip through check.
expect "encoded dash link passes check" 0 "- Dash [q]($dash_out)"
if "$checker" link "$page" "not on the page" >/dev/null 2>&1; then
  echo "FAIL link accepted text not on the page"
  failures=$((failures + 1))
else
  echo "ok   link rejects text not on the page"
fi

echo
[ "$failures" -eq 0 ] && echo "all passed" || echo "$failures failed"
[ "$failures" -eq 0 ]
