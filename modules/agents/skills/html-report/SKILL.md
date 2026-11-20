---
name: html-report
description: Deliver a long report as one HTML page instead of a long chat message, so the user only reads the conclusion and the decisions they must make. Use when a final report would exceed about three lines of prose, contains a table, compares options, or shows before/after edits. Not for design.md or other files that belong in the repository.
---

# HTML Report

The user's bottleneck is judgment, not reading speed.
A narrow chat pane cannot show tables, comparisons, or side-by-side diffs, so long reports go into one HTML page and the chat carries only what needs the user.

## Chat message

The chat reply contains only:

1. The conclusion in one or two sentences.
2. The page URL (or file path).
3. The decisions the user must make, each as one line. Omit this if there are none.

Everything else lives in the page.

## Page content rules

- **Decisions sit where they arise.** Put each decision point next to the paragraph it concerns, visually highlighted (e.g. a red-bordered box), never collected at the end.
- **Every decision has options and a recommendation.** List concrete options, mark the recommended one, and give its reason in one line.
- **Silence means OK.** State at the top which items will be applied as-is unless the user comments on them, so the user does not have to approve each one.
- **Before/after side by side.** Show edits as two columns (before left, after right) with the surrounding paragraph and what the section is about, so the user can judge without reopening the source.
- **One proposal, not three.** Apply the recommended option and show the result. Offer a second alternative only when genuinely unsure.
- **Do not add.** No history of how you got here, no excuses, no rejected alternatives, no repeated lists, no caveats that do not change a decision.
- **Prefer a figure or table** over paragraphs whenever the content is structural (flows, comparisons, status of many items).

Write Japanese pages in the document register required by the `japanese-writing` skill.

## Page format

- One self-contained `.html` file: inline CSS, no external assets, no build step.
- Readable on a phone: viewport meta, max-width body, no horizontal scroll, tables wrapped in an `overflow-x: auto` container.
- Light and dark themes via `prefers-color-scheme`.
- `<title>` names the topic in a few words; the first line of the page repeats the conclusion.

## Publishing

Write the file to the session scratchpad (or a temp dir), then pick the first destination that applies:

1. `~/.config/html-report/destination` exists: run `scripts/publish.sh <file.html> [<project-slug>]` (path relative to this skill). It prints the URL or absolute path to put in the chat. It fails loudly if the file is missing or malformed; do not work around that by guessing a path.
2. The Artifact tool is available: publish the file as an Artifact and use its link.
3. Otherwise: give the absolute file path.

Never put secrets or credentials in a page; published pages are reachable from every device of the user.
