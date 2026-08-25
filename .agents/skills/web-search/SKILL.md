---
name: web-search
description: Search the web using the agent-search CLI (search). Use for any question requiring current or external information.
---

# Web Search

Uses the [`search`](https://github.com/paperfoot/search-cli) CLI (crate: `agent-search`), a single Rust binary that aggregates 13+ search providers (Exa, Brave, Serper, Tavily, Jina, Perplexity, etc.) with rank fusion.

## Prerequisites

- `search` binary installed at `~/.local/bin/search`
- `EXA_API_KEY` environment variable set (get one free at https://dashboard.exa.ai — no credit card required)

## Usage

### General web search

```bash
~/.local/bin/search "<query>" --json -c 10
```

Auto-detects JSON output when piped. Use `--json` explicitly when running interactively.

### Mode-specific search

```bash
~/.local/bin/search -m academic "LLM quantization methods" --json
~/.local/bin/search -m news "latest AI regulation" --json
~/.local/bin/search -m people "John Smith CEO" --json
~/.local/bin/search -m social "rust programming" --json
```

Available modes: `general`, `news`, `academic`, `scholar`, `people`, `social`, `patents`, `images`, `places`, `deep`, `extract`, `scrape`, `similar`.

### Extract page content

```bash
~/.local/bin/search -m extract "https://example.com/article" --json
~/.local/bin/search -m scrape "https://example.com" --json  # alias
```

Uses Stealth → Jina → Firecrawl → Browserless fallback chain. Handles JS-heavy and anti-bot pages.

### Use specific provider

```bash
~/.local/bin/search -p exa "<query>" --json
~/.local/bin/search -p brave,serper "<query>" --json
```

### Health check

```bash
~/.local/bin/search doctor --json
```

Test-fires every configured provider and reports status.

### Capability discovery

```bash
~/.local/bin/search agent-info --json
```

Returns the full routing map: which modes route to which providers, with descriptions.

## Output format

The `--json` flag returns a structured envelope:

```json
{
  "status": "success",
  "query": "...",
  "mode": "general",
  "results": [{ "title": "...", "url": "...", "snippet": "..." }],
  "answers": [],
  "metadata": {
    "elapsed_ms": 1500,
    "result_count": 10,
    "providers_queried": ["exa", "brave"]
  }
}
```

## Setup (one-time)

```bash
# 1. Install (already done — ~/.local/bin/search)
# 2. Get API key from https://dashboard.exa.ai
# 3. Set environment variable (add to shell init or nix config)
export EXA_API_KEY="your-key-here"
# 4. Verify
~/.local/bin/search doctor --json
```
