#!/usr/bin/env bash
set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <bw_item_name> <target_file_path>"
    echo "Example: $0 \"SSH key\" \"\$HOME/.ssh/id_ed25519\""
    exit 1
fi

BW_KEY_NAME="$1"
TARGET_PATH="$2"
TARGET_DIR=$(dirname "$TARGET_PATH")

# 保存先ディレクトリが存在しない場合は作成する
if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    chmod 700 "$TARGET_DIR"
fi

echo "Fetching \"$BW_KEY_NAME\" from Bitwarden..."
rbw get "$BW_KEY_NAME" > "$TARGET_PATH"
chmod 600 "$TARGET_PATH"

echo "Successfully restored to: $TARGET_PATH"
