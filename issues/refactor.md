# 作業計画書：sops-nixを用いたNix認証トークンの安全な管理と実装

## 1. 目的

GitHub.com および GitHub Enterprise (GHE) のプライベートリポジトリにアクセスするための認証トークンを `sops-nix` で管理し、`nix-darwin` の `nix.conf` に安全に注入する。これにより、Flake inputs の解決における「鶏と卵」問題を解消し、宣言的な管理を実現する。

## 2. 構成要素

* **秘密管理**: `sops-nix` (ageを使用)
* **対象ファイル**: `/etc/nix/access-tokens.conf` (Nix store外に配置)
* **インクルード形式**: `nix.extraOptions = "!include /etc/nix/access-tokens.conf";`

## 3. 実装ステップ

### ステップ 1: SOPSファイルの作成

暗号化された秘密情報ファイルを生成する。

* 以下の構造を持つ `secrets/tokens.yaml` を作成。
* GitHub.com用（個人/仕事）および GHE用のキーを定義。
* `sops` コマンドで暗号化。

### ステップ 2: Nix モジュールの実装 (`modules/sops-tokens.nix`)

以下のロジックを実装する。

1. `sops.secrets."nix_access_tokens"` の定義。
2. `sops.placeholder` を使用した `content` の動的生成。
* 形式: `access-tokens = github.com=TOKEN1 github.com=TOKEN2 my-ghe.com=TOKEN3`


3. `nix.extraOptions` への `!include` 命令の追加。

### ステップ 3: 構成の二重化 (`flake.nix`)

「鶏と卵」問題を回避するため、`darwinConfigurations` を2段階に分ける。

1. **`bootstrap` 構成**:
* プライベートな `inputs` に依存しない構成。
* `sops-tokens.nix` を含み、トークンファイルの生成のみを目的とする。


2. **`default` (またはマシン名) 構成**:
* 全てのプライベート `inputs` (Home Manager等) を含む完全な構成。



## 4. エージェントへの具体的指示

### 指示 1: ファイル作成

> `modules/sops-tokens.nix` を作成してください。`sops.placeholder` を使い、`secrets/tokens.yaml` 内の複数のトークンを `access-tokens = host=token ...` の形式で `/etc/nix/access-tokens.conf` に書き出す設定を記述してください。また、`nix.extraOptions` にそのファイルをインクルードする設定を追加してください。

### 指示 2: Flake の構成変更

> `flake.nix` を編集し、`darwinConfigurations.bootstrap` を追加してください。この構成は、プライベートリポジトリを `inputs` に持つ Home Manager モジュールを除外し、`sops-tokens.nix` のみを適用するようにしてください。

## 5. 完了条件 (Definition of Done)

1. `sops` で暗号化された秘密情報から `/etc/nix/access-tokens.conf` が正しく生成されること。
2. `nix show-config | grep access-tokens` を実行した際、シークレットファイルの内容が反映されていること。
3. `!include` 設定により、トークンファイルが物理的に存在しない初回時でも `nix-darwin` のビルドが（パブリックリポジトリのみで）通ること。

---

## 6. セットアップ・ガイド（人間用）

実装完了後、以下の手順で初期構築を行ってください。

1. **トークンの準備**: GitHub で PAT を作成し、SSO を承認（Authorize）する。
2. **初回適用 (Bootstrap)**:
```bash
# 初回のみ環境変数でトークンをブリッジする
export NIX_CONFIG="access-tokens = github.com=ghp_your_token"
darwin-rebuild switch --flake .#bootstrap

```


3. **フル構成の適用**:
```bash
# 以降はトークン不要
unset NIX_CONFIG
darwin-rebuild switch --flake .#your-machine-name

```