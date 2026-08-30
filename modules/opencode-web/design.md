# OpenCode Web Design

## Purpose

OpenWebUIの代わりにopencode webをChat UIとして利用し、
Obsidian vaultとZoteroの横断検索を提供する。

## Why opencode web

- **組み込みWeb UI**: 会話履歴、モデル選択、ツール実行表示が標準装備
- **組み込みツール**: grep, bash, read等の検索ツールがそのまま利用可能
- **既存設定の活用**: opencode.json（llama-swap接続設定）をそのまま利用
- **低コスト**: Python検索ツールの実装が不要
- **低保守**: 保守対象が大幅に削減（自前Pythonコードなし）

## Architecture

```
ユーザー → ブラウザ → Caddy → opencode web (launchd) → llama-swap
                                                     ↓
                                              grep/zot/obsidian CLI
```

## Tools

opencodeの組み込みツールを活用する:

- `grep` (ripgrep): Obsidian vault内のMarkdownファイル検索
- `bash`: `zot search`、`open obsidian://`等のコマンド実行
- `read`: ファイル内容の読み取り

## Agent

`opencode-web`エージェント（`agents/opencode-web.md`）が検索指示を定義する:

- 検索対象パスの指定
- zotコマンドの使い方
- 回答スタイル

## Non-Goals

- OpenWebUIの構築・運用
- Python検索ツールの実装
- Chat UIの自前実装
- ベクトル検索・埋め込みインデックス

## Constraints

- opencode webは単一ユーザー向け（認証はPocketID SSOで対応）
- 起動時にvaultディレクトリにcdする必要がある
- llama-swapが起動している必要がある（mac-mini-m4-pro）

## Rejected Alternatives

- **OpenWebUI + Pythonプラグイン**: 実装コストが高い（10-15日）。Python検索ツール3つの実装が必要。
- **自前Chat UI**: WebSocketラッパーの実装が必要。維持コストが高い。
- **ベクトル検索**: インデックス更新の管理が複雑。grep + zotで十分と判断。
