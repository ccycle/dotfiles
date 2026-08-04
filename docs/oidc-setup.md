# Pocket ID OIDC セットアップ手順

Pocket ID を IdP として各 self-hosted サービスへ SSO を組み込む手順。
一度だけ行う手動ブートストラップが中心で、それ以外は Nix 設定に集約されている。

前提: `darwin-rebuild.sh <profile>` が成功し、Pocket ID コンテナが healthy であること。

## 0. サービス構成の前提

| サービス | クライアント種別 | 認証方式 |
|----------|-----------------|----------|
| OpenCloud | public / PKCE | Web/Desktop/Mobile のネイティブ OIDC |
| Forgejo | confidential | OIDC |
| GitLab | confidential | OmniAuth (OIDC) |
| Immich | confidential | OIDC |
| Grafana | confidential | generic OAuth (OIDC) |
| Prometheus | - | Caddy basicauth (OIDC非対応のため) |

host は `mac-mini-m4-pro` を例にする（他 host では内部ドメインが異なる）。

## 1. Pocket ID 初期セットアップ

ブラウザで `https://auth.<host>.internal/setup` を開き、管理者ユーザーの
作成とパスキー登録を行う。この操作はブラウザ + WebAuthn が必須で、
自動化できない（passkey 登録は対話的操作）。

## 2. OpenCloud 用グループ作成

OpenCloud のロールマッピングには Pocket ID のグループ + custom claim を使う。

Pocket ID admin → Groups → Create group で以下 4 グループを作成:

| Group name | Custom Claim key | Custom Claim value |
|------------|------------------|--------------------|
| `opencloud_admins` | `opencloud_role` | `opencloudAdmin` |
| `opencloud_spaceadmins` | `opencloud_role` | `opencloudSpaceAdmin` |
| `opencloud_users` | `opencloud_role` | `opencloudUser` |
| `opencloud_guests` | `opencloud_role` | `opencloudGuest` |

各グループの Custom Claims タブで claim を追加する。その後、管理者ユーザーを
`opencloud_admins` グループに追加する（Groups → グループ → Users タブ）。
ユーザーがいずれかのグループに属さないと OpenCloud は 500 を返す。

## 3. OIDC クライアント作成

Pocket ID admin → OIDC Clients → Create client。

### OpenCloud (4 クライアント, すべて public / PKCE)

Web クライアントは Pocket ID が自動生成する Client ID (UUID) をそのまま使う。
Desktop / Android / iOS の3クライアントは OpenCloud アプリ側で client ID が
ハードコードされているため、**Show Advanced Options から Client ID を
固定値に上書き**する。上書きしなければ「クライアントが見つからない」
エラーになる。

| Name | Client ID | Callback URLs | Logout Callback URL |
|------|-----------|---------------|---------------------|
| OpenCloud Web | (自動生成UUIDのまま) | `https://opencloud.<host>/`<br>`https://opencloud.<host>/oidc-callback.html`<br>`https://opencloud.<host>/oidc-silent-redirect.html` | `https://opencloud.<host>` |
| OpenCloud Desktop | `OpenCloudDesktop` (上書き) | `http://127.0.0.1`<br>`http://localhost` | (任意) |
| OpenCloud Android | `OpenCloudAndroid` (上書き) | `oc://android.opencloud.eu` | (任意) |
| OpenCloud iOS | `OpenCloudIOS` (上書き) | `oc://ios.opencloud.eu` | (任意) |

Public Client と PKCE を有効にする。Web クライアントは自動生成された UUID を
そのまま `modules/opencloud/options.nix` の `OPENCLOUD_OIDC_CLIENT_ID` /
`OPENCLOUD_OIDC_PROXY_CLIENT_ID` に転記する。public クライアントの ID は
秘密情報ではないため sops secret は不要。

### その他サービス (confidential)

| サービス | Client ID | Callback URL | Logout Callback URL |
|----------|-----------|--------------|---------------------|
| Forgejo | 任意 (e.g. `forgejo`) | `https://forgejo.<host>/user/oauth2/callback` | 同じ |
| GitLab | 任意 (e.g. `gitlab`) | `https://gitlab.<host>/users/auth/openid_connect/callback` | 同じ |
| Immich | 任意 (e.g. `immich`) | `https://immich.<host>/auth/login`<br>`https://immich.<host>/user-settings`<br>`app.immich:///oauth-callback` | `https://immich.<host>/auth/login`<br>`https://immich.<host>/user-settings` |
| Grafana | 任意 (e.g. `grafana`) | `https://grafana.<host>/login/generic_oauth` | 同じ |

Public Client を有効にしないこと（confidential のまま）。保存後に発行される
**Client Secret をコピー**して次のステップで sops に投入する。

## 4. グループ制限の設定

各 OIDC クライアントの設定画面で Allowed Groups に `opencloud_admins` 等を
追加する。この設定をすると**クライアントを利用できるユーザーがグループ所属者に
制限される**。未設定のまま Allowed Groups を ON にすると誰もログインできず
`access_denied` になる。

## 5. sops への本番値投入

confidential クライアントの Client ID / Secret を各モジュールの
`secrets.yaml` に入れる:

| モジュール | sops キー |
|-----------|-----------|
| `modules/forgejo/secrets.yaml` | `forgejo_oidc_client_id`, `forgejo_oidc_client_secret` |
| `modules/gitlab/secrets.yaml` | `gitlab_oidc_client_id`, `gitlab_oidc_client_secret` |
| `modules/immich/secrets.yaml` | `immich_oidc_client_id`, `immich_oidc_client_secret` |
| `modules/monitoring/secrets.yaml` | `grafana_oidc_client_id`, `grafana_oidc_client_secret` |

```sh
sops set modules/forgejo/secrets.yaml '["forgejo_oidc_client_id"]' '"<CLIENT_ID>"'
sops set modules/forgejo/secrets.yaml '["forgejo_oidc_client_secret"]' '"<CLIENT_SECRET>"'
```

## 6. Prometheus basicauth の設定

Prometheus は OIDC 非対応のため、Caddy の basicauth を使う。

```sh
# bcrypt ハッシュ生成
nix run nixpkgs#caddy -- hash-password --plaintext <PASSWORD>
```

ハッシュを host profile (`modules/mac-mini-m4-pro/darwin.nix` など) の
`services.monitoring.prometheusAuthHash` に設定する。

## 7. 適用

```sh
scripts/darwin-rebuild.sh <profile>
```

## 8. 動作確認

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
