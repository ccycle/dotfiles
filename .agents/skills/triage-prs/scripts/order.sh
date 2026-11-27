#!/usr/bin/env bash
set -euo pipefail

tail -n +2 | while IFS=$'\t' read -r n _ head _; do
  printf '%s\t\n' "$n"
  git diff --name-only "origin/main...$head" | sed "s/^/$n\t/"
done | awk -F'\t' '
  { seen[$1] }
  $2 != "" {
    k = split(owners[$2], o, " ")
    for (i = 1; i <= k; i++) { pair[$1 SUBSEP o[i]]; pair[o[i] SUBSEP $1] }
    owners[$2] = owners[$2] " " $1
  }
  END {
    for (p in pair) { split(p, ab, SUBSEP); shared[ab[1]]++ }
    for (n in seen) print shared[n] + 0 "\t" n
  }' | sort -n -k1,1 -k2,2 | cut -f2 | paste -sd' ' -
