# Pocket ID OIDC セットアップ手順

Pocket ID を IdP として各 self-hosted サービスへ SSO を組み込む手順。
OIDC クライアントとグループの登録は `scripts/pocket-id-register-clients.sh`
で自動化されており、手動操作は Pocket ID の初期セットアップと管理 API
キーの作成のみ。クライアント定義は Nix 設定が唯一の情報源である。

前提: `darwin-rebuild.sh <profile>` が成功し、Pocket ID コンテナが healthy
であること。

## 0. サービス構成の前提

| サービス | クライアント種別 | 認証方式 | 登録される Client ID |
|----------|-----------------|----------|----------------------|
| OpenCloud Web | public / PKCE | OIDC | `opencloud-web` |
| OpenCloud Desktop | public / PKCE | ネイティブ OIDC | `OpenCloudDesktop` |
| OpenCloud Android | public / PKCE | ネイティブ OIDC | `OpenCloudAndroid` |
| OpenCloud iOS | public / PKCE | ネイティブ OIDC | `OpenCloudIOS` |
| Forgejo | confidential | OIDC | `forgejo` |
| Immich | confidential | OIDC | `immich` |
| Grafana | confidential | generic OAuth (OIDC) | `grafana` |
| Reports (static-reports) | confidential | oauth2-proxy forward_auth | `reports` |
| GitLab | - | - | (両 host で無効のため未登録) |
| Prometheus | - | Caddy basicauth (OIDC非対応) | - |

Client ID は固定文字列である。OAuth のモデル上 client ID は秘密ではなく
識別子に過ぎず、セキュリティは confidential クライアントの自動生成
secret・public クライアントの PKCE・グループ制限で担保される。OpenCloud の
Desktop / Android / iOS は client ID がアプリにハードコードされているため、
この値が必須である（大文字小文字を含めて一致させること）。

host は `mac-mini-m4-pro` を例にする（他 host では内部ドメインと
`secrets-<host>.yaml` の名前が異なる）。

## 1. Pocket ID 初期セットアップ

ブラウザで `https://auth.<host>.internal/setup` を開き、管理者ユーザーの
作成とパスキー登録を行う。この操作はブラウザ + WebAuthn が必須で、
自動化できない（passkey 登録は対話的操作）。

## 2. 管理 API キーの作成（手動・一度きり）

Pocket ID admin → Settings → API Keys で API キーを作成し、その host の
sops secrets に投入する。

```sh
sops set modules/pocket-id/secrets-<host>.yaml '["pocket_id_admin_api_key"]' '"<KEY>"'
```

## 3. 登録スクリプトの実行

```sh
scripts/pocket-id-register-clients.sh --admin-user <管理者ユーザー名> [--dry-run]
```

このスクリプトは宣言型設定
（`services.pocket-id.oidcClients` / `oidcGroups`、各サービスのモジュールが
`modules/pocket-id/options.nix` のオプションに宣言）を Pocket ID 管理 API
と同期する。処理内容は以下の通り。

- **グループ**: 4 つの OpenCloud グループを作成し、`opencloud_role` claim
  （`opencloudAdmin` / `opencloudSpaceAdmin` / `opencloudUser` /
  `opencloudGuest`）を設定する。
- **クライアント**: 存在しなければ作成、既存なら宣言に合わせて更新する。
  各クライアントに宣言どおりの Callback / Logout Callback URL、PKCE、
  group restriction（Allowed Groups）を設定する。
- **confidential クライアントの secret**: 作成時に
  `POST /api/oidc/clients/{id}/secret` で secret を生成し、対応する
  sops secrets ファイルに自動で書き込む。sops 側の値が
  `CHANGE_ME_fake_client_secret` 等のプレースホルダのままの場合は、
  クライアントを作り直して新しい secret を発行する。
- **管理者ユーザー**: `--admin-user` で指定したユーザーを
  `opencloud_admins` グループに追加する（未存在なら作成する）。
  ユーザーがいずれかのグループに属さないと OpenCloud は 500 を返すため、
  この手順は省略しないこと。
- **後片付け**: 手動登録時代に残っていた `*_oidc_client_id` の sops キーを
  削除する（各 host の自分の secrets ファイルのみ）。

`--dry-run` は API キーなしでも動作し、実行計画のみを表示する。

### クライアント定義の変更・追加

新しいサービスを追加する場合、そのサービスモジュールで
`services.pocket-id.oidcClients` にクライアントを、必要なら
`oidcGroups` にグループを宣言してから、再度スクリプトを実行する。
スクリプトは冪等なので何度実行してもよい。

## 4. 適用

sops に書き込まれた変更をコミットしてから適用する。

```sh
git add -A && git commit -m "Register OIDC clients on Pocket ID"
scripts/darwin-rebuild.sh <profile>
```

## 5. Prometheus basicauth の設定

Prometheus は OIDC 非対応のため、Caddy の basicauth を使う。

```sh
# bcrypt ハッシュ生成
nix run nixpkgs#caddy -- hash-password --plaintext <PASSWORD>
```

ハッシュを host profile (`modules/mac-mini-m4-pro/darwin.nix` など) の
`services.monitoring.prometheusAuthHash` に設定する。

## 6. 動作確認

各サービスのログイン画面で「Pocket ID でログイン」を選択し、パスキーで
サインインできることを確認する。エラー時の調査は:

- **`access_denied`**: ユーザーがクライアントの Allowed Groups に属しているか
  確認（Pocket ID DB の `user_groups_users` / `oidc_clients_allowed_user_groups`）。
- **500 (OpenCloud)**: `PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM` 等の env が
  コンテナに渡っているか確認。`docker exec opencloud-opencloud-1 env | grep OIDC`。
  グループ未所属でも 500 になる。

## 既知の問題・対応

- **OrbStack で `/run/secrets/` の bind mount が使えない**: OrbStack の Linux VM は
  `/run/` を共有しないため、Pocket ID の encryption key は launchd スクリプトで
  `/tmp/pocket_id_encryption_key` にコピーしてから mount している
  (`modules/pocket-id/options.nix`)。chmod 444 にしないとコンテナ内から
  読めない。
- **client secret を変更したら**各サービスの launchd を再起動する
  (`sudo launchctl kickstart -k system/org.nixos.<service>-compose`)。
- **手動登録時代の sops キー**: スクリプトが `*_oidc_client_id` キーを
  削除する。GitLab は両 host で無効のため、`gitlab_oidc_client_secret` の
  プレースホルダは残ったままで問題ない。
