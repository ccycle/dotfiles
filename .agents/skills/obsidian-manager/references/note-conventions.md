# Note Conventions for the Zettelkasten Vault

Style guide for writing notes in `$HOME/Obsidian/zettelkasten` on the user's behalf.
Extracted from the user's own meta-notes (`Obsidianの運用ルール.md`, `自分用ノートの整理整頓の仕方考察.md`, `ZoteroとObsidianを使ってZettelkastenする.md`) and from observation of ~2,900 existing notes.
Any draft that violates these rules will read as foreign to the user and defeat the purpose of delegation.

## Core principles

1. **Speed over polish.**
   The vault is optimized for fast capture; notes are allowed to stay short, rough, and unfinished.
   Do not "complete" a note beyond what its conclusion needs.
2. **Title = conclusion.**
   The filename IS the note's claim, often a full Japanese sentence.
   Example: `LLMが指示を守らない問題に対しては毎チャットルールを出力させるのが効果的.md`.
   One claim per note; if a draft contains two conclusions, split it into two notes.
3. **Don't fear duplicates.**
   Writing a note that overlaps an existing one is acceptable; the user merges later.
   When you know of an overlapping note, mention it to the user, but still produce the draft.
4. **Flat placement.**
   Concept notes live directly in the vault root.
   Never create topic folders; folders in the vault are learning-source containers (books, languages) or tool-generated areas, not a taxonomy.

## Body style

- **Complete and faithful content.**
  Drafts must capture the full substance of the source without omissions or additions. Do not summarize away details, and do not insert information the source did not contain.
- **Include background, solution, and outcome.**
  When the source describes a problem or question, the draft must always include the background context (what the problem was), the proposed solution or approach, and the result or conclusion. Omitting any of these three weakens the note's usefulness.
- **No headings.**
  `#` headings belong to daily notes and generated notes, not concept notes.
  (A trailing `## References` section listing `[[@citekey]]` links is the one accepted exception, from the Zotero workflow.)
- **Link-base wikilinks.**
  Link at the word/concept level with `[[...]]` — e.g. `- link baseで書く` becomes `- [[link base]]で書く`.
  Dangling links to notes that do not exist yet are intentional design, not errors; create them freely.
- **No tags.** Tags are an explicitly deprecated rule (廃止ルール); inline links replace them.
- **No frontmatter.**
  Hand-authored notes carry no YAML frontmatter; the filename carries the meaning.
  Frontmatter in this vault marks machine-generated notes.
- **Language mix.**
  Reasoning and prose in Japanese; technical terms, code, commands, and library names stay in English inline.
  Open questions are written as plain bullets, often ending in `？` — leaving questions unanswered in a note is normal.
- **Length.**
  Most notes are under ~10 lines.
  A researched draft may be longer, but prefer splitting into linked notes over one long note.

## Note types and do-not-touch zones

Agent-authored drafts are always **concept notes** (root-level, per the rules above).
The following areas are machine-generated or template-driven; read them for context, but never edit them and never imitate their format:

| Area                                                | What it is                                                                                |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `ReferenceNotes/@*.md`                              | Zotero mdnotes exports; regenerated, hand edits get overwritten. Cite as `[[@<citekey>]]` |
| `Clippings/`                                        | Web clipper output with its own frontmatter                                               |
| `copilot-conversations/`, `copilot-custom-prompts/` | Copilot plugin artifacts                                                                  |
| `予定メモ *.md`                                     | Templater-generated schedule memos                                                        |
| `YYYYMMDD.md`                                       | Daily notes (`# YYYY-MM-DD` heading, timestamped bullets)                                 |
| `Templater/`, `MDNotes_templates/`                  | Templates                                                                                 |
| `Excalidraw/`                                       | Drawings                                                                                  |

## Reference example

A representative concept note (`LLMが指示を守らない問題に対しては毎チャットルールを出力させるのが効果的.md`):

```markdown
- [Claude Codeの「すぐルール忘れる問題」を解決する超効果的な方法を見つけた気がする](https://zenn.dev/sesere/articles/0420ecec9526dc)
- これ毎チャット出力させると圧迫感あるからもう少し工夫でなんとかならないかな？
  - 例えば指示と異なる作業をし始めたときに「ルールを表示してください」と指示するとか？
```

Note the pattern: conclusion in the title, sources as top-level bullets, the user's own doubt as a question bullet, indentation with tabs.
