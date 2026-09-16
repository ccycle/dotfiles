# OpenCode Web Design

## Purpose

Use `opencode web` as the chat UI instead of OpenWebUI to provide cross-sectional search across the Obsidian vault and Zotero library.

## Why opencode web

- **Built-in Web UI**: Conversation history, model selection, and tool execution visualization come out of the box.
- **Built-in Tools**: Search tools like `grep`, `bash`, and `read` are immediately usable.
- **Reuse of Existing Configuration**: Leverages existing `opencode.json` (such as llama-swap connection settings) as-is.
- **Low Cost**: Eliminates the need to implement custom Python search tools.
- **Low Maintenance**: Significantly reduces the maintenance surface area (no custom Python code).

## Architecture

```
User → Browser → Caddy → opencode web (launchd) → llama-swap
                                                     ↓
                                              grep/zot/obsidian CLI
```

## Tools

Leverages opencode's built-in tools:

- `grep` (ripgrep): Search Markdown files within the Obsidian vault.
- `bash`: Execute commands such as `zot search`, `open obsidian://`, etc.
- `read`: Read file contents.

## Agent

The `opencode-web` agent (`agents/opencode-web.md`) defines search instructions:

- Target paths to search
- Usage of the `zot` command
- Response style

## Non-Goals

- Deploying and operating OpenWebUI.
- Implementing custom Python search tools.
- Building a custom chat UI from scratch.
- Vector search or embedding-based indexing.

## Constraints

- `opencode web` is designed for a single user (authentication handled via Pocket ID SSO).
- Must `cd` into the vault directory at startup.
- Requires `llama-swap` to be running (`mac-mini-m4-pro`).
- Assumes `zot` runs in `--local` mode (configured personally via `~/.config/zotcli/config.ini`). While note search via the Zotero Web API only matches the first line of a note, `--local` mode queries the Zotero desktop app's native search engine (full-text note index) directly, bypassing this limitation. Because of this prerequisite, the `zotero-keepalive` launchd agent keeps `Zotero.app` running continuously (`brewCasks.zotero` only installs the app without auto-starting it).

## Rejected Alternatives

- **OpenWebUI + Python Plugins**: High implementation cost (10–15 days). Requires writing three custom Python search tools.
- **Custom Chat UI**: Requires implementing a WebSocket wrapper. High maintenance burden.
- **Vector Search**: Complex index update management. Deemed that `grep` + `zot` is sufficient. Even after re-evaluating when real-world queries failed to match, we retained the policy of having the agent perform multi-angle exploration (re-searching with synonyms and related terms, inspecting title listings) rather than introducing embedding indices.
- **Full-Text Search via Zotero Note Dump / Sync**: Since `--local` mode already searches Zotero desktop's full-text note index, an additional dump/sync pipeline was deemed unnecessary.
- **Nix Option for zot Authentication Mode**: Personal Zotero credentials are treated like passwords; rather than exposing them as declarative options like `obsidian.vaults`, manual configuration in `~/.config/zotcli/config.ini` is preserved.
