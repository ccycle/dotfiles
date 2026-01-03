# sops-nix 運用方針

本リポジトリでは、`sops-nix` を **System (nix-darwin)** と **User (Home Manager)** の両方で使用します。
それぞれの役割と管理範囲を明確に分離することで、競合を防ぎつつ適切な権限管理を行います。

## 1. System Level (nix-darwin)

- **モジュール**: `modules/darwin/sops.nix` (または `darwin.nix` に直接記述)
- **サービス名**: `org.nixos.sops-nix`
- **権限**: root 権限で実行されます。
- **復号キー**: ホストの SSH 鍵 (`/etc/ssh/ssh_host_ed25519_key`) を使用します。
- **保存場所**: `/run/secrets/` (または `/run/org.nixos.sops-nix/`)
- **主な用途**:
  - システム全体で共有する設定 (e.g., `nix.conf` の `access-tokens`)
  - root 権限が必要なサービスの設定
  - システムデーモン用の認証情報

## 2. User Level (Home Manager)

- **モジュール**: `modules/home-manager/sops.nix`
- **サービス名**: `org.nix-community.home.sops-nix`
- **権限**: ログインユーザーの権限で実行されます。
- **復号キー**: ユーザー個人の Age 鍵 (`~/.config/sops/age/keys.txt`) または GPG 鍵を使用します。
- **保存場所**: `$XDG_RUNTIME_DIR/secrets/` (例: `/run/user/<UID>/secrets/`) や `~/.config/sops-nix/secrets/`
- **主な用途**:
  - 個人の開発用 API トークン (GitHub PAT, AWS Keys, etc.)
  - ユーザーアプリケーションの設定ファイル (`~/.config/` 配下への埋め込み)
  - SSH 秘密鍵 (`~/.ssh/id_*`) の管理

## 競合について

System レベルと User レベルは、それぞれ独立したサービスとして動作し、異なる保存場所を使用するため **競合しません**。
両者を有効化することで、システム管理と個人の開発環境の管理を安全かつ柔軟に行うことができます。
