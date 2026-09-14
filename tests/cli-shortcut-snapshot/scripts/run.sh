#!/usr/bin/env bash
# VHS-based CLI shortcut snapshot suite.
#
# Modes:
#   run.sh [tape]          Record .webm for human review (default)
#   run.sh --check [tape]  Run tape, assert structural markers from .assertions file
#
# See ../design.md for the full rationale.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SUITE_DIR/../.." && pwd)"

MODE="record"
case "${1:-}" in
--check)
  MODE="check"
  shift
  ;;
esac

TAPE="${1:-$SUITE_DIR/tapes/herdr-reviewr-toggle.tape}"
if [ ! -f "$TAPE" ]; then
  echo "Tape not found: $TAPE" >&2
  echo "Usage: $0 [--check] [path/to/*.tape]" >&2
  exit 1
fi
TAPE_NAME="$(basename "$TAPE" .tape)"
TAPE_DIR="$(cd "$(dirname "$TAPE")" && pwd)"
ASSERTIONS_FILE="$TAPE_DIR/${TAPE_NAME}.assertions"

BRANCH_SLUG="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD | tr '/' '-')"
SERVICE_NAME="cli-shortcut-snapshot/${TAPE_NAME}"
REPORTS_BASE_DIR="/var/lib/static-reports"
REPORTS_DIR="$REPORTS_BASE_DIR/${BRANCH_SLUG}/${SERVICE_NAME}"
REPORTS_RETENTION_DAYS=14

WORK_DIR="$(mktemp -d)"
OUT_WEBM="$WORK_DIR/${TAPE_NAME}.webm"
VHS_TXT_BASENAME="${TAPE_NAME}-snapshot-$$.txt"
OUT_TXT="$WORK_DIR/${TAPE_NAME}.txt"
export SESSION_NAME="cli-shortcut-snapshot-$$"

cleanup() {
  herdr session stop "$SESSION_NAME" >/dev/null 2>&1 || true
  herdr session delete "$SESSION_NAME" >/dev/null 2>&1 || true
  if [ "$MODE" = "record" ] && [ -f "$OUT_WEBM" ] && mkdir -p "$REPORTS_DIR" 2>/dev/null; then
    rm -rf "${REPORTS_DIR:?}"/*
    cp "$OUT_WEBM" "$REPORTS_DIR/demo.webm"
    cp "$SCRIPT_DIR/player.html" "$REPORTS_DIR/index.html"
    echo "[cli-shortcut-snapshot] published: https://reports.$(scutil --get LocalHostName 2>/dev/null || hostname -s).internal/${BRANCH_SLUG}/${SERVICE_NAME}/" >&2
  fi
  if [ -d "$REPORTS_BASE_DIR" ]; then
    find "$REPORTS_BASE_DIR" -mindepth 3 -maxdepth 3 -type d -mtime "+${REPORTS_RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true
    find "$REPORTS_BASE_DIR" -mindepth 1 -type d -empty -exec rmdir {} + 2>/dev/null || true
  fi
  # Clean up VHS's .txt from repo root if it landed there
  rm -f "$REPO_ROOT/$VHS_TXT_BASENAME" 2>/dev/null || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$REPO_ROOT"

EFFECTIVE_TAPE="$TAPE"
VHS_ARGS=()
case "$MODE" in
record)
  VHS_ARGS+=(-o "$OUT_WEBM")
  ;;
check)
  # Inject Output directive for .txt capture
  EFFECTIVE_TAPE="$WORK_DIR/${TAPE_NAME}-with-txt.tape"
  {
    echo "Output ${VHS_TXT_BASENAME}"
    cat "$TAPE"
  } >"$EFFECTIVE_TAPE"
  ;;
esac

env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID \
  nix develop "$REPO_ROOT#cli-shortcut-snapshot" -c \
  vhs "$EFFECTIVE_TAPE" ${VHS_ARGS[@]+"${VHS_ARGS[@]}"}

if [ "$MODE" = "record" ]; then
  exit 0
fi

# --check: extract last frame, run assertions
mv "$REPO_ROOT/$VHS_TXT_BASENAME" "$OUT_TXT"

FRAME="$WORK_DIR/last-frame.txt"
"$SCRIPT_DIR/extract-last-frame.sh" "$OUT_TXT" >"$FRAME"

if [ ! -f "$ASSERTIONS_FILE" ]; then
  echo "FAIL: no assertions file for ${TAPE_NAME}" >&2
  echo "  expected: ${ASSERTIONS_FILE#"$REPO_ROOT/"}" >&2
  exit 1
fi

failed=0
while IFS= read -r pattern; do
  [[ $pattern =~ ^[[:space:]]*# ]] && continue
  [[ -z ${pattern// /} ]] && continue
  if ! grep -qE "$pattern" "$FRAME"; then
    echo "FAIL: pattern not found: $pattern" >&2
    failed=1
  fi
done <"$ASSERTIONS_FILE"

if [ "$failed" -eq 0 ]; then
  echo "PASS: ${TAPE_NAME} — all assertions matched." >&2
else
  echo "" >&2
  echo "Last frame was:" >&2
  cat "$FRAME" >&2
  exit 1
fi
