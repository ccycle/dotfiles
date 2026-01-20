#!/usr/bin/env bash
set -e

SECRETS_FILE="$1"

if [ -z "$SECRETS_FILE" ]; then
  echo "Usage: $0 <path/to/secrets.yaml>"
  exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
  echo "File '$SECRETS_FILE' does not exist. Creating new secrets file..."
  # You might want to add default .sops.yaml lookup or key specification here
  sops "$SECRETS_FILE"
else
  sops "$SECRETS_FILE"
fi
