---
name: unslop
description: Remove AI-sounding patterns from English prose — filler, hype vocabulary, hedges, forced triplets, decorative formatting, figurative language — without changing its meaning. Use when writing or revising English text people will read (commit messages, PR descriptions, docs, design.md, skill files) or when asked to unslop, tighten, or de-AI English writing. For Japanese text, use the japanese-writing skill instead.
---

# Unslop

Scan the text for the patterns below and rewrite the sentences that hit them.
Keep facts, numbers, names, code, links, and the intended tone unchanged.

## Words

- Drop AI vocabulary: additionally, crucial, delve, enhance, foster, landscape, pivotal, showcase, testament, underscore, vibrant, seamless, robust.
- Use the plain verb: "use", not "utilize" or "leverage"; "is" or "has", not "serves as", "stands as", "boasts".
- Replace abstract metaphor nouns (substrate, vector, primitive, paradigm, flywheel, north star) with the concrete thing.
- Cut adverbs, or replace them with a stronger verb or a number.
- Cut filler: "in order to" becomes "to"; delete "it is important to note that".
- Keep at most one hedge per claim.

## Sentences

- One idea per sentence; split any sentence a reader would reread.
- Active voice with a named actor, unless the actor is unknown or irrelevant.
- No trailing "-ing" clause that adds no fact ("…, ensuring reliability").
- No "not just X, but Y" and no "from X to Y" unless X and Y sit on a real scale.
- Do not force items into groups of three.
- Name a source or delete a vague attribution ("experts say").
- Say what something does, with the mechanism or the number, not how it feels.
  Delete any sentence that would fit unchanged in another project's docs.
- Use one name per thing and repeat it instead of rotating synonyms.
- Write whole sentences; spell out arrows and ad-hoc abbreviations.

## Openings and endings

- No praise or agreement openers; start with the answer.
- No chatbot closers ("Hope this helps", "Let me know if").
- No generic conclusion; end on a specific fact or next step.

## Formatting

- Sentence-case headings.
- No decorative emoji, no bold on every proper noun, and no bold label that just restates its line.
- Prefer a period or comma over a dash used as a clause break.
- A colon introduces a list or an example, not a mid-sentence pivot.
- Straight quotes.
- In this user's repositories, keep one sentence per line in multi-sentence prose.

## Sources

Adapted (rewritten, not copied) from the `unslop` skill in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
