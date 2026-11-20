---
name: japanese-writing
description: Rules for writing natural Japanese and for revising stilted, translated-sounding, or AI-sounding Japanese without changing its meaning. Use whenever you write a Japanese reply, document, commit message, report, or artifact, and when the user asks to fix, proofread, or naturalize Japanese text.
---

# Japanese Writing

LLMs tend to produce stilted Japanese that reads like a literal translation from English.
Apply these rules when writing Japanese, and use the revision workflow when asked to fix existing text.
They do not fully remove the translated feel, but they improve consistency and readability.

## Writing rules

- Match the sentence-ending register to the output channel, and keep it consistent within that output — do not mix registers:
  - Chat replies addressed directly to the user (conversational turns): 丁寧語 (です/ます).
  - Written documents saved to a file or persisted artifact (design.md, reports, memory notes, artifacts, commit/PR descriptions): 論文体 — である/する調 only (never だ止め), objective and formal, avoiding colloquial expressions and first-person casual phrasing.
- Keep sentences short. Avoid nesting multiple clauses into one long sentence.
- Prefer the simpler verb form over a verbose construction (e.g. 「〜することができます」より「〜できます」、「〜を行う」より対応する動詞そのもの).
- Avoid the over-explicit subject repetition typical of literal English-to-Japanese translation; omit the subject when it's clear from context, as natural Japanese does.
- Avoid empty preambles such as 「〜については、」「〜に関して、」 when they add no information.
- Don't overuse bullet lists for content that reads better as plain prose; reserve bullets for genuinely parallel items.
- Avoid unnecessary katakana loanwords when a natural Japanese term already exists.
- Noun-ending sentences (体言止め): do not use them in running prose or explanatory text — end those sentences with a conjugated verb or adjective. Noun-ending is acceptable in headings and bullet-list item labels.
- Do not format list items as a bold label followed by a colon or dash (`- **重要**: …`), and do not prefix list items with decorative emoji (✅ 🚀 💡 🎯).
  Write the label as plain text, or fold it into the sentence.
- Avoid hype and absolute claims (革命的, ゲームチェンジャー, 究極の, 完全に解決, すべての課題を解決, 魔法のように, 可能性を解き放つ).
  State what actually happens, with its scope and limits.

**Examples (before → after, shown in document register — である/する調; for chat replies, apply the same simplification but end in です/ます):**

- Before: 「このエラーはネットワーク接続の問題によって発生している可能性があります。」
  After: 「このエラーはおそらくネットワーク接続の問題で起きている。」
- Before: 「設定ファイルを変更することで、この動作を変更することができます。」
  After: 「設定ファイルを変更すれば、この動作を変更できる。」
- Before (体言止めの多用): 「原因は設定ミス。対応は再起動。」
  After: 「原因は設定ミスである。再起動すれば直る。」

**After drafting Japanese text:** before finalizing, re-scan the draft against the rules above — register-vs-channel mismatch, sentence-ending consistency, and 体言止め are the easiest violations to miss — and rewrite any sentence that breaks it.

## Revising existing text

Use this when the user hands you Japanese text to fix, rather than when you write your own.

### Preserve meaning

The goal is style, not content.
Never change any of the following:

- Facts, numbers, dates, proper nouns, and technical terms.
- Quotations, URLs, code, tables, and citations.
- Conditions, negations, obligations and prohibitions, and who is responsible for what.
- The author's register (敬体/常体) and stance, unless the user asks for a different register.

Do not add claims, examples, numbers, experiences, or reasons that the original does not contain.
Do not mechanically remove every passive voice, inanimate subject, loanword, or abstract noun; keep those the context needs.
For legal, medical, financial, contractual, or specification text, be conservative.

### Workflow

1. Identify the purpose, the reader, and the register, and mark the spans that must not change.
2. Find violations of the writing rules above.
3. Rewrite locally, sentence by sentence.
   Restructure paragraphs only when the uniform, mechanical structure is the main readability problem and the order of the argument survives.
4. Put any change you are not sure preserves meaning in a separate list of proposals instead of applying it.
5. Re-read the rewrite against the original and confirm every item under "Preserve meaning" survived.

### Output

By default, output only the revised text, with no preamble or commentary.
If some changes were held back as proposals, list them after the text.
If the user asks for reasons, append a short table:

```text
| 変更箇所 | 修正後 | 理由 |
| --- | --- | --- |
| することができます | できます | 冗長な表現を簡潔にした |
```

## Sources

Ideas adapted (rewritten, not copied) from these MIT-licensed projects:

- [geonwoo-jeong/japanese-humanizer](https://github.com/geonwoo-jeong/japanese-humanizer): meaning-preservation constraints, proposal-only handling, reason table.
- [textlint-ja/textlint-rule-preset-ai-writing](https://github.com/textlint-ja/textlint-rule-preset-ai-writing): bold-label and emoji list items, hype expressions.
