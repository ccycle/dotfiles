# Pi Web Design

## Purpose

pi coding agentのWeb UIを提供し、ブラウザからコーディングセッションを管理する。

## Why Pi Web

- **ブラウザベース**: ターミナル不要でアクセス可能
- **マルチセッション**: 複数のコーディングセッションを並列管理
- **ファイルブラウザ**: プロジェクトファイルの閲覧・アップロード
- **Git統合**: ワークツリー切り替え、差分表示
- **設定UI**: モデル・プロバイダー設定をブラウザから管理

## Architecture

```
ユーザー → ブラウザ → Caddy → pi-web (launchd) → pi agent
                                                ↓
                                         ~/.pi/agent/sessions
```

## Agent Data

pi-webはpi agentのデータを直接読み込む:
- セッションファイル: `~/.pi/agent/sessions/<encoded-cwd>/<timestamp>_<uuid>.jsonl`
- 設定ファイル: `~/.pi/agent/`内

## Non-Goals

- opencode webの機能複製（別サービスとして提供）
- リモートアクセス（ローカルネットワーク限定）

## Constraints

- Node.js 22.19.0以上が必要
- pi agentがインストールされている必要がある
- ローカルネットワーク内でのみアクセス可能（セキュリティ考慮）
