# iOS Articles Archive

Jekyll site (GitHub Pages) archiving articles and a handbook about iOS engineering.
Entries live in `_articles/` (dated `YYYY-MM-DD-slug.md`) and `_handbook/` (`slug.md`).
Front matter reference: `CONTRIBUTING.md`.

## Adding or editing an entry

Do all of these in the same change:

1. **Create the entry**: `ruby scripts/new_article.rb "Title"` (`--handbook`, `--source URL`), then write
   the body and `summary`. Leave `keywords: []`.
2. **Korean translation** — required for every entry not written in Korean. Write it yourself;
   there is no translation API or script. See the rules below.
3. **Stamp it**: `ruby scripts/translations.rb --stamp _articles/ko/<same file name>`
   (fills in `lang`, `translation_of`, `translation_hash`, date, author, source_url).
4. **Keywords**: `ruby scripts/keywords.rb` (assigns them to the original and copies them to the translation).
5. **Verify**: `ruby scripts/translations.rb --check` and `ruby scripts/keywords.rb --check` both pass.

When an original is **edited**, `translations.rb --check` reports its translation as stale:
update the translation to match, then stamp it again.

Korean-language entries get `lang: ko` in front matter and need no translation.

## Translation rules

- Path: same file name in a `ko/` subfolder — `_articles/ko/2025-01-22-actor-reentrancy-explained.md`.
- Front matter: write only `title` and `summary` (translated); `--stamp` and `keywords.rb` add the rest.
- Natural Korean in 합니다체, the style of Korean tech blogs — not word-for-word.
- Keep the Markdown structure exactly: headings, lists, tables, links, images.
- Copy fenced code blocks and inline code verbatim, including comments inside code blocks.
- Keep terms Korean iOS engineers use in English (SwiftUI, actor, Sendable, retain cycle, …) in English.
  For terms with a common Korean form, use it with the English in parentheses on first use,
  e.g. 동시성(concurrency), 순환 참조(retain cycle).
- Translate everything else; don't summarize, omit, add content, or add a translator's note
  (the site shows a translation notice automatically).
- Existing examples: `_articles/ko/`, `_handbook/ko/`.

## Keywords

Taxonomy: `_data/keywords.yml`. If `keywords.rb` misses an entry's main topic, add an alias
(English or Korean) to the taxonomy rather than hand-editing keywords.

## Checking the site

```sh
bundle install
bundle exec jekyll build   # or `serve` → http://localhost:4000/ios-articles-archive/
```
