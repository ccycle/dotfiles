---
name: attic-credentials
description: Manage Attic JWT secret, CI token, and per-client push tokens. Initializes the atticd JWT signing key, generates operator tokens via atticadm, and handles rotation with sops encryption.
---

# Attic Credentials

Nix binary cache (Attic) のトークン管理スキル。
atticd の JWT secret 初期化、操作用トークンの生成・ローテーションを行う。

トークン発行は atticd と同じホスト上で動く `atticadm make-token`(サーバ管理コマンド)を使う。
クライアント CLI の `attic token *` はこのバージョンには存在しない。

## 前提

- atticd が mac-mini-m4-pro で稼働している (init.sh でこれから起動することも可)
- SSH で mac-mini-m4-pro に接続可能。`atticadm-jwt-secret` (`/run/secrets/atticd-jwt-secret`)
  を読むため、接続先で `sudo cat` がパスワード無しで通ること
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
5. `generate-token.sh ci` を呼び出し `ci` トークンを生成・sops 暗号化。plain text も表示 (Forgejo Secrets 登録用)

クライアント毎のトークンは初回セットアップに含まれない。クライアントを追加するたびに
`generate-token.sh client <machine>` を個別に実行する。

### `generate-token.sh` — トークン生成

```bash
skills/project/attic-credentials/scripts/generate-token.sh ci
skills/project/attic-credentials/scripts/generate-token.sh client <machine>
```

`atticadm make-token --sub <sub> --push dotfiles --validity 10y` をサーバ上で実行し、
sops 暗号化して `modules/attic/secrets.yaml` に書き込む。

- `ci`: sub は `ci`。plain text を stdout に出力 (Forgejo UI 貼り付け用)
- `client <machine>`: sub は `<machine>`。生成後、そのマシンで実行する
  `attic login` コマンドを stdout に出力する

### `rotate-token.sh` — トークンローテーション

```bash
skills/project/attic-credentials/scripts/rotate-token.sh ci
skills/project/attic-credentials/scripts/rotate-token.sh client <machine>
```

1. 同じ sub で新しいトークンを生成し sops 暗号化 (`modules/attic/secrets.yaml` の該当キーを上書き)
2. JWT はステートレスなため個別失効はできない。旧トークンは 10 年の有効期限まで技術的には
   有効のままなので、単体の入れ替えで十分か・`atticd-jwt-secret` ごと再生成して
   全トークンを無効化する必要があるかをスクリプトの出力が案内する

## ワークフロー

### 初回セットアップ

1. `init.sh` を実行
2. 表示された公開鍵を `bootstrap/modules/attic/darwin.nix` の `trusted-public-keys` に追記
3. 表示された CI トークンを Forgejo の "Settings → Actions → Secrets" に `ATTIC_CI_TOKEN` として登録

### クライアントの push を有効化する (マシン毎に手動 1 回)

1. Caddy のルート CA をキーチェーンへ登録
   (`curl -fsSL http://ca.mac-mini-m4-pro.internal/ca.crt` → `security add-trusted-cert -d -r trustRoot`。
   GUI 認可が挟まるため自動化不可)
2. `generate-token.sh client <machine>` を実行し、出力された `attic login` コマンドを
   対象マシンで実行する
3. 以降、対象マシンでの `darwin-rebuild switch` 実行時に自動で push される
   (`scripts/darwin-rebuild.sh` 参照)

### トークンローテーション

`rotate-token.sh ci` / `rotate-token.sh client <machine>`
