#!/bin/sh
set -eu

VAULT_NAME="zettelkasten"
COMMAND_ID="obsidian-livesync:livesync-replicate"

show_usage() {
  echo "Usage: $(basename -- "$0") [--command <id>]"
  echo ""
  echo "Trigger Obsidian LiveSync sync via Advanced URI."
  echo ""
  echo "Options:"
  echo "  --command <id>  Command ID to execute (default: ${COMMAND_ID})"
  echo "  --help, -h      Show this help"
  echo ""
  echo "Available commands:"
  echo "  obsidian-livesync:livesync-replicate   Replicate now (default)"
  echo "  obsidian-livesync:livesync-toggle       Toggle LiveSync"
  echo "  obsidian-livesync:livesync-abortsync    Abort synchronization"
  echo "  obsidian-livesync:livesync-suspendall   Toggle All Sync"
  echo "  obsidian-livesync:livesync-scan-files   Scan files"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --command)
      [ $# -lt 2 ] && echo "Error: --command requires an argument" >&2 && exit 1
      COMMAND_ID="$2"
      shift 2
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      show_usage >&2
      exit 1
      ;;
  esac
done

# URL-encode the colon
encoded_cmd=$(printf '%s' "${COMMAND_ID}" | sed 's/:/%3A/g')
uri="obsidian://adv-uri?vault=${VAULT_NAME}&commandid=${encoded_cmd}"

echo "Triggering: ${COMMAND_ID}"
echo "URI: ${uri}"
open "${uri}"
echo "Done."
