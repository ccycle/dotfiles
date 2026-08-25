# `darwin-rebuild` ネットワーク障害

## ステータス: 修正実装済み・適用ブロック中

## エラー内容

```
error: unable to download 'https://cache.nixos.org/yssfy93sfrnvz7c3glkbfvy3bz7g4bwd.narinfo':
Could not connect to server (7) Failed to connect to cache.nixos.org port 443
```

## 根本原因

en0 は **IPv6 オンリー環境**（フレッツ光 MAP-E/DS-Lite）:

1. en0 に IPv4 アドレス・デフォルトルートがない
2. Nix の libcurl は **c-ares** で DNS 解決 → デフォルトで IPv4 優先接続（Happy Eyeballs）
3. IPv4 ルートなし → `Network is unreachable` で失敗
4. `curl -6` 指定すれば c-ares 付き curl でも正常接続（確認済み）
5. c-ares **なし**の curl（macOS ネイティブ DNS）は IPv6 優先で問題なく動作

## 修正内容（実装済み）

`darwin.nix` に nixpkgs overlay を追加し、nix パッケージが使う curl から c-ares を除去:

```nix
nixpkgs.overlays = [
  (final: prev: {
    nixDependencies = prev.nixDependencies.overrideScope (dfinal: dprev: {
      curl = prev.curl.override { c-aresSupport = false; };
    });
  })
];
```

### なぜ `nix.override { curl = ... }` ではないのか

nix パッケージはモジュラー構成（`everything.nix` → `nix-store` → `curl`）で、
トップレベルの `nix` パッケージは `curl` を直接引数として受け取らない。
`curl` は `nixDependencies` スコープ経由で `nix-store` 等のサブパッケージに注入されるため、
`nixDependencies.overrideScope` でスコープ内の `curl` を差し替える必要がある。

### 検証状況

- Nix syntax check: **成功**
- Nix evaluation (`--impure`): **成功**（overlay が正しく評価される）
- Build dry-run: ネットワーク接続エラー（現行 nix の c-ares 問題そのもの — 期待通り）

## ブートストラップ問題（未解決）

overlay を適用するには `darwin-rebuild switch` が必要だが、
ビルド自体がネットワーク問題で失敗する **鶏と卵の問題** がある。

### 試行した回避策

| 回避策                                 | 結果                                                       |
| -------------------------------------- | ---------------------------------------------------------- |
| `--option substitute false`            | ソース fetch も nix daemon の curl 経由 → 失敗             |
| system curl で GitHub から手動 DL      | github.com が **IPv6 非対応** → 到達不能                   |
| system curl `-6` で tarballs.nixos.org | nix source の NAR hash で 404（tarball hash ではないため） |
| releases.nixos.org から DL             | nix 2.31.2 の source tarball が存在しない                  |

### 失敗の構造

```
overlay 適用には darwin-rebuild switch が必要
  → nix の再ビルドが必要
    → ソース fetch (github.com) が必要
      → github.com は IPv6 非対応 → 到達不能
    → 代替: substituter (cache.nixos.org) からバイナリ DL
      → overlay 適用後の nix は custom build → cache に存在しない
      → 仮に存在しても現行 nix の c-ares 問題で DL 不能
```

### 未検討の回避策候補

1. **Tailscale 経由で別マシンから nix closure をコピー**
   - diskstation (100.104.190.9) に nix がインストールされていれば `nix copy` 可能
   - ただし `nix copy` 自体も nix daemon のネットワークを使用する可能性
2. **SSH SOCKS プロキシ**
   - `ssh -D 1080 100.104.190.9` で SOCKS5 プロキシを設定
   - nix daemon の環境変数 `https_proxy=socks5h://localhost:1080` を設定
   - launchd plist の修正が必要
3. **NAT64/DNS64 の設定**
   - ルーターまたはローカルで NAT64 を設定し IPv4 宛通信を IPv6 経由に変換
4. **IPv4 が使える環境で一度ビルド**
   - テザリング等で一時的に IPv4 接続し `darwin-rebuild switch` を実行
5. **cache.nixos.org から system curl で NAR を手動 DL → nix store にインポート**
   - overlay なしの stock nix バイナリを cache から取得可能（IPv6 対応）
   - ただし stock nix も c-ares 問題あり → 根本解決にならない

## 調査の経緯

### 確認済みの事実

| 項目                                             | 結果                    |
| ------------------------------------------------ | ----------------------- |
| `curl` (システム) → cache.nixos.org              | `curl -6` で成功        |
| `curl` (システム) → github.com                   | **失敗**（IPv6 非対応） |
| `curl -6 -sI https://cache.nixos.org`            | 成功 (HTTP/2 200)       |
| `curl -6 -sI https://tarballs.nixos.org`         | 成功 (HTTP/2 200)       |
| `nc -6 -z cache.nixos.org 443`                   | 成功                    |
| `nix store info --store https://cache.nixos.org` | **失敗**                |
| `nix store info` (ローカル daemon)               | 成功                    |
| `nix eval` (ビルド評価自体)                      | `--impure` 付きで成功   |
| github.com AAAA レコード                         | **なし**（IPv6 非対応） |
| cache.nixos.org AAAA レコード                    | あり（Fastly CDN）      |
| tarballs.nixos.org AAAA レコード                 | あり（Fastly CDN）      |

### 原因の絞り込み

- **ネットワーク自体は IPv6 で正常** — system curl `-6` で cache.nixos.org 等に接続可能
- **IPv4 は完全に不通** — en0 に IPv4 アドレスなし、デフォルトルートなし
- **github.com は IPv6 非対応** — AAAA レコードなし、到達不能
- **nix の libcurl 固有の問題** — c-ares の Happy Eyeballs が IPv4 優先 → 失敗

## 環境情報

- ホスト: mac-mini-m4 (aarch64-darwin)
- Nix: 2.31.2
- libcurl: 8.17.0 (OpenSSL 3.6.0, c-ares 1.34.5)
- ネットワーク: Ethernet (en0), IPv6 only (MAP-E/DS-Lite)
- Tailscale: 有効 (100.74.134.72)
- dnsmasq: 稼働中
- macOS ファイアウォール: 有効 (incoming のみ)
