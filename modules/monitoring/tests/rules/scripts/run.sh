#!/usr/bin/env bash
set -euo pipefail

SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="$(cd "$SUITE_DIR/../.." && pwd)"
IMAGE="$(yq -e '.services.prometheus.image' "$MODULE_DIR/compose.yaml")"

docker run --rm --entrypoint sh \
  -v "$MODULE_DIR:/module:ro" -w /module/tests/rules \
  "$IMAGE" -c 'promtool test rules *.test.yml'
