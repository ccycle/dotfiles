#!/usr/bin/env bash
# Extracts the last complete frame from a VHS .txt output.
# VHS concatenates all rendered frames separated by lines of ─ (U+2500).
# This grabs the block between the last two separators and strips
# leading/trailing blank lines and trailing whitespace per line.
set -euo pipefail
file="${1:?usage: extract-last-frame.sh <vhs-output.txt>}"

seps=($(grep -n '^─\+$' "$file" | cut -d: -f1))
n=${#seps[@]}
if [ "$n" -lt 2 ]; then
  echo "error: fewer than 2 frame separators in $file (found $n)" >&2
  exit 1
fi
start=$((seps[n - 2] + 1))
end=$((seps[n - 1] - 1))
sed -n "${start},${end}p" "$file" |
  sed 's/[[:space:]]*$//' |
  awk 'NF{p=1; for(i=1;i<=b;i++) print ""; b=0; print; next} p{b++}'
