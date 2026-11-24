---
name: research
description: Mandatory workflow for researching external information (documentation, specs, product behavior, versions, papers, news) on the web. Every claim must cite a Text Fragment link that highlights the supporting passage, and the report must pass a citation checker before it is shown. Use whenever the user asks to research, look up, survey, compare, or fact-check something whose answer lives on the web. For the state of local systems, files, or services, use measure-first instead.
---

# Research: Cited Web Investigation

A claim the user cannot check in one click is a liability.
A URL alone is not enough: a plausible URL can be invented, and a real page can fail to say what the claim says.
Every web citation therefore links to the exact supporting passage with a Text Fragment (`#:~:text=`).
The browser highlights that passage, and `scripts/check-citations` verifies that the passage exists on the page.

`check-citations` below means `scripts/check-citations` next to this file (deployed as `~/.agents/skills/research/scripts/check-citations`).
It needs only `python3`, plus `pdftotext` for PDF sources.

## 1. Decompose the question into claims

Restate the question as claims that a single passage on a page could support or refute.
Write down what would settle each claim before searching.

## 2. Find and read the sources

Search with whatever web search tool is available, then fetch and read the actual page.
Never cite a page you have not fetched in this session, and never cite from a search snippet alone.

Prefer primary sources in this order: official documentation or specification, the project's own repository or changelog, the vendor's announcement, then reputable secondary sources.
When sources disagree, cite each of them and report the disagreement instead of picking one silently.

## 3. Build each citation from the fetched text

Copy the supporting passage verbatim from the fetched page text, never from memory or paraphrase.
Then build the link with the checker, which refuses to print a link whose text is not on the page:

```bash
check-citations link "<page url>" "<verbatim passage>"
# long passages: give the first few words and the last few words
check-citations link "<page url>" "<start words>" "<end words>"
```

Keep the passage short and distinctive (a sentence or less), and keep it in the source's language even when the report is in another language.
For a passage longer than about six words, use the `start,end` form with three to five distinctive words at each end: the browser still highlights the whole passage, and the URL stays short.

If `link` fails, the page text the checker sees differs from what you read.
The error reports how many characters of text it extracted; a small count usually means a bot wall or a JavaScript-rendered page.
Find another source that states the same fact.
If none exists, mark the claim `[unverifiable]` and say why; never weaken or reword a passage until it happens to match.

## 4. Write the report as claims with footnote citations

Write the report to a Markdown file (in the scratchpad unless the user names a location).
Every top-level list item is a claim, and every claim carries at least one citation or the marker `[unverifiable]` with a reason.
Cite with a footnote reference such as `[^1]` at the end of the claim, so the claim reads as one short line.
Put the footnote definitions after all claims, each on its own line and holding the quote as link text and the source name after it:

```markdown
- A Text Fragment URL makes the browser jump to a given passage.[^1]
- Safari's first supported version is disputed between sources.[^2][^3]
- Whether vendor X plans to support it [unverifiable]: no public statement found.

[^1]: [“Text fragments link directly to specific text”](https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Fragment/Text_fragments#:~:text=Text%20fragments%20link%20directly%20to%20specific%20text) (MDN)

[^2]: [“Safari 16.1”](<link 1>) (source A)

[^3]: [“Safari: 18.2”](<link 2>) (source B)
```

For a `start,end` link, write the quote as `“<start words> … <end words>”`.
Number footnotes in order of first use and reuse a number when two claims cite the same passage.
Local files may also be cited as relative links with line anchors, such as `[home.nix](home.nix#L12-L20)`, resolved against the report's directory.
Keep conclusions and interpretation outside the list, and make them follow only from the cited claims.

## 5. Check before showing the report (mandatory)

```bash
check-citations check <report.md>
```

Fix every `FAIL` line and run it again until it exits 0.
Do not show the user a report that has not passed, and do not skip this step for small questions.
Then give the user the conclusion and the claims in chat in the same footnote layout, with the footnote definitions as the last lines of the reply, so the URLs stay out of the text the user reads.
When the reply would exceed about three lines of prose, follow the `html-report` skill instead and render the footnotes as the page's numbered source list.

The checker proves only that each quoted passage exists on its page.
Whether the passage actually supports the claim is still your responsibility; reread each claim next to its quote before finalizing.
