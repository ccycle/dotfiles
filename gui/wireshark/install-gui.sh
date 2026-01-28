#!/bin/bash
set -euo pipefail

# https://www.wireshark.org/download/osx/
WIRESHARK_VERSION="4.6.3"
DMG_URL="https://www.wireshark.org/download/osx/Wireshark%20${WIRESHARK_VERSION}.dmg"
DMG_FILE="$HOME/Downloads/Wireshark ${WIRESHARK_VERSION}.dmg"
VOLUME_NAME="Wireshark ${WIRESHARK_VERSION}"

# ダウンロード (Downloadsフォルダに保存、既存ファイルがあればスキップ)
download_dmg() {
  echo "Downloading Wireshark ${WIRESHARK_VERSION} to Downloads folder..."
  curl -L -o "$DMG_FILE" "$DMG_URL"
}

if [[ -f "$DMG_FILE" ]]; then
  echo "DMG file already exists at: $DMG_FILE"
  echo "Verifying DMG file..."
  if hdiutil verify "$DMG_FILE" > /dev/null 2>&1; then
    echo "DMG file is valid. Skipping download..."
  else
    echo "DMG file is corrupted or incomplete. Re-downloading..."
    rm -f "$DMG_FILE"
    download_dmg
  fi
else
  download_dmg
fi

# マウント
echo "Mounting DMG..."
hdiutil attach "$DMG_FILE"

# Wiresharkアプリ本体をコピー
echo "Installing Wireshark.app..."
sudo cp -R "/Volumes/${VOLUME_NAME}/Wireshark.app" /Applications/

# ChmodBPF (パケットキャプチャ権限用) もインストール
echo "Installing ChmodBPF (for packet capture permissions)..."
sudo installer -pkg "/Volumes/${VOLUME_NAME}/Install ChmodBPF.pkg" -target /

# アンマウント
echo "Unmounting DMG..."
hdiutil detach "/Volumes/${VOLUME_NAME}"

echo "Wireshark ${WIRESHARK_VERSION} installation complete!"
echo "DMG file remains at: $DMG_FILE"