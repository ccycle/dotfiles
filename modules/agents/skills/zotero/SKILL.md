---
name: zotero
description: Search the local Zotero library (metadata, attachment full text, PDF files) via the zot CLI. Use when the user asks about papers, books, or PDFs stored in Zotero, or whether a Zotero item's content is readable.
---

# Zotero via zot CLI

Always use `--local` mode (reads the running Zotero desktop app, no API key needed). If the command fails to connect to `localhost:23119`, Zotero.app is not running — tell the user to start it.

## 1. Find items

`--qmode everything` is mandatory (the default `titleCreatorYear` only matches title/creator/year, missing full text and notes).

```bash
zot --local items list -q "<query>" --qmode everything --output json
```

Parse `key`, `data.itemType`, `data.title` from the JSON. Retry with synonyms in Japanese and English when the first query misses (users often misremember terms). For a broad overview, omit `-q` to list candidate titles.

## 2. Inspect a hit

```bash
zot --local items get <KEY> --output json
zot --local items children <KEY>
```

`children` lists attachments/notes. A PDF attachment shows `contentType: application/pdf` and its on-disk path in `links.enclosure.href` (`file:///Users/.../Zotero/storage/...`). A web snapshot shows `contentType: text/html`.

## 3. Read content

Indexed full text (no PDF parsing needed):

```bash
zot --local fulltext get <ATTACHMENT_KEY>
zot --local fulltext get <ATTACHMENT_KEY> --output raw_content
```

The JSON output includes `indexedPages`/`totalPages` plus text. For the raw file (e.g. to hand to a PDF reader):

```bash
zot --local files download <ATTACHMENT_KEY> -o <path>
```
