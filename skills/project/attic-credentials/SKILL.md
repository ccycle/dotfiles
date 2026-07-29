---
name: attic-credentials
description: Manage Attic JWT secret, watch-store token, and CI token. Initializes the atticd JWT signing key, generates operator tokens, and handles rotation with sops encryption.
---

# Attic Credentials

Nix binary cache (Attic) のトークン管理スキル。
atticd の JWT secret 初期化、操作用トークンの生成・ローテーションを行う。

## 前提

- atticd が mac-mini-m4-pro で稼働している (init.sh でこれから起動することも可)
- SSH で mac-mini-m4-pro に接続可能
- ローカルに `sops` と `openssl` がインストール済み
- 環境変数 `SOPS_AGE_KEY_FILE` または `SOPS_AGE_KEY` が設定済み (sops の復号化のため)

## スクリプト

### `init.sh` — 初回セットアップ

```bash
skills/project/attic-credentials/scripts/init.sh
```

以下の処理を順に実行:

1. `atticd-jwt-secret` が未作成なら生成し、sops 暗号化して `modules/attic/secrets.yaml` に書き込む
2. SSH 越しに `darwin-rebuild switch` を実行し atticd を起動
3. SSH 越しに `attic cache create dotfiles` を実行 (idempotent)
4. SSH 越しに `attic cache info dotfiles` を実行し公開鍵を表示
5. `watch-store` トークンを生成し sops 暗号化
6. `ci` トークンを生成し sops 暗号化、plain text も表示 (Forgejo Secrets 登録用)

### `generate-token.sh <role>` — トークン生成

```bash
skills/project/attic-credentials/scripts/generate-token.sh watch-store
skills/project/attic-credentials/scripts/generate-token.sh ci
```

有効期限 10 年でトークンを生成し、sops 暗号化して `modules/attic/secrets.yaml` に書き込む。
role が `ci` の場合、Forgejo UI に貼り付けるための plain text も stdout に出力する。

### `rotate-token.sh <role>` — トークンローテーション

```bash
skills/project/attic-credentials/scripts/rotate-token.sh watch-store
skills/project/attic-credentials/scripts/rotate-token.sh ci
```

1. 新しいトークンを生成し sops 暗号化
2. 古いトークンは `attic token list` で確認し手動で `attic token revoke <hash>` を実行するよう案内
3. role が `ci` の場合、新しいトークンの plain text も出力 (Forgejo UI 更新用)

## ワークフロー

### 初回セットアップ

1. `init.sh` を実行
2. 表示された公開鍵を `bootstrap/modules/attic/darwin.nix` の `trusted-public-keys` に追記
3. 表示された CI トークンを Forgejo の "Settings → Actions → Secrets" に `ATTIC_CI_TOKEN` として登録

### トークン追加

`generate-token.sh <role>`

### トークンローテーション

`rotate-token.sh <role>`
