---
name: pdf-on-demand
description: Read PDFs page by page and figure by figure instead of dumping whole documents into context, so long books and paper reading stay within rate limits. Use whenever a task involves reading, searching, quoting, summarising, or extracting figures from a PDF (including Zotero attachments), before reaching for whole-document extraction such as `zot fulltext get`.
---

# PDF On-Demand Reading

Reading a whole PDF is the single most common way an agent burns its context and rate limit. Read the smallest part that answers the question, and let local tools do the searching.

Measured on a 420-page technical book (Japanese, 469k characters, 90 figures):

| Approach | Cost |
|---|---|
| Whole-book text in context | ~235k–470k tokens (unusable) |
| `zot fulltext get <attachment>` | 113,609 chars, **and only 100 of 420 pages indexed** |
| One page of text (default mode) | ~3.2 KB, ~1.1k tokens |
| One page as image at 120 dpi | ~1.3k tokens |
| **Same page cropped to the figure only** | **~280 tokens** |

Two facts drive the rules below: a page image costs about as much as a page of text, and cropping the region of interest cuts that by roughly 4.5x.

## Commands

`pdfread` below means `scripts/pdfread` next to this file (deployed as `~/.agents/skills/pdf-on-demand/scripts/pdfread`). It needs poppler-utils, `shasum`, and `python3`, all already installed here. It has two subcommands: `find` (locate pages without dumping text) and `fig` (crop a figure region). Text reading is a plain `pdftotext` call — do not wrap it.

## Locate before reading

Never open a PDF at page 1 and walk forward. Find the page numbers first.

```bash
zot --local items list -q "<query>" --qmode everything --output json   # find the item
zot --local items children <KEY>                                       # find the PDF path
pdfread find <pdf> "<regex>"       # page numbers + matching lines only, cached
```

`find` caches a text dump under `$TMPDIR/pdfread` and reuses it until the PDF is newer, so repeated searching costs nothing. It prints at most 40 matching lines, truncated to 110 characters each, plus a hit count — enough to choose pages, not enough to fill the context.

## Read only the chosen range

```bash
pdftotext -f 25 -l 30 "<pdf>" -              # plain text, ~1.1k tokens per page
pdftotext -layout -f 25 -l 30 "<pdf>" -       # only for tables and code listings
```

Each page is ~3.2 KB in plain mode. `-layout` pads lines out to column position and costs about 35% more, so use it only when alignment carries meaning. Read 5–10 pages at a time; widen only if the answer is not there.

The book's table of contents is usually the cheapest map: read those few pages once, then target chapters.

## Figures

`pdfimages` is not a shortcut here. Diagrams in typeset books (InDesign, LaTeX, Word) are vector drawings, so `pdfimages` returns only decorative rasters — in the measured book, 40 embedded images out of 90 figures. Rasterise the page region instead.

```bash
pdfread fig <pdf> 25 140 340 640 330     # X Y W H in pixels at that dpi
```

It prints the output path with pixel dimensions and the approximate token cost, so you can judge before reading the image. Coordinates are pixels from the top-left at the chosen DPI (default 120). To find them, render the page once at 120 dpi with `pdftoppm -f 25 -l 25 -r 120 -png -singlefile "<pdf>" /tmp/page", read it, and reuse the region for neighbouring figures of the same layout instead of re-rendering.

120 dpi is readable for body-size labels. Raise to 150–200 dpi only when text inside the figure is genuinely too small, and crop tighter rather than raising DPI — tokens scale with area.

## Hard rules

- **Never use `zot --local fulltext get`.** It returns partial indexes in one large blob. Use `pdfread find` + `pdftotext -f/-l` instead.
- **Never paste a whole book or a whole chapter.** If a summary of a whole book is wanted, build it by reading chapter by chapter and taking notes, not by loading everything at once.
- **Do not re-render the same page twice.** The script caches by file, page, crop, and DPI; reuse the printed path.
- **Search locally, read narrowly.** grep and the `find` subcommand are free; only what enters the conversation costs tokens.
- If the PDF has no text layer (`pdftotext` returns almost nothing), say so and ask before running OCR — OCR of a whole book is expensive.
