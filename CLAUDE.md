# iOS Articles Archive

Jekyll site (GitHub Pages) archiving articles and a handbook about iOS engineering.
Entries live in `_articles/` (dated `YYYY-MM-DD-slug.md`) and `_handbook/` (`slug.md`).
Front matter reference: `CONTRIBUTING.md`.

## Archiving an article: read → summary → keyword → archive

When the user gives an article (URL, PDF, or pasted text), do all of these in one change:

1. **Read** the whole article. If the URL is blocked, ask for a PDF or pasted text. Never write
   from the title or from memory. Note the title, author, and publication date.
2. **Summary**: create the entry with
   `ruby scripts/new_article.rb "Title" --source URL --author "Name" --date YYYY-MM-DD`,
   then write it in the summary format below. Also write its Korean version (translation rules below)
   unless the entry is already in Korean, and stamp it:
   `ruby scripts/translations.rb --stamp _articles/ko/<same file name>`.
3. **Keyword**: `ruby scripts/keywords.rb`. If the article's main topic is missing, add an alias to
   `_data/keywords.yml` and re-run with `--force <file>` rather than hand-editing keywords.
4. **Archive**: verify with `ruby scripts/translations.rb --check` and `ruby scripts/keywords.rb --check`,
   build the site, then commit and open a PR.

Handbook pages (`--handbook`) are our own writing, so they use the same steps but a free-form body.

### Summary format (every archived article)

Other people's articles are copyrighted: archive **a summary and notes in our own words**, never
the full text. Keep the original's structure of ideas, and credit it with `author` and `source_url`.

- `summary` front matter: one or two sentences with the core idea (shown in search results).
- Body:
  1. A one-line blockquote crediting the author with a link to the original.
  2. `## Summary`: two or three paragraphs covering the problem, the approach, and what the article builds.
  3. `## Key points`: bullets naming the concrete APIs and techniques, each with what it does.
  4. `## Notes` (optional): our own context such as OS requirements, caveats, or when to use what.
     Code here must be our own short illustration, never copied from the article.
- Quote at most a phrase; don't reproduce the article's code listings or images.

## Translation rules

- Path: same file name in a `ko/` subfolder — `_articles/ko/2024-09-24-mastering-container-views-in-swiftui-basics.md`.
- Front matter: write only `title` and `summary` (translated); `--stamp` and `keywords.rb` add the rest.
- Natural Korean in 합니다체, the style of Korean tech blogs — not word-for-word.
- Keep the Markdown structure exactly: headings, lists, tables, links, images.
- Copy fenced code blocks and inline code verbatim, including comments inside code blocks.
- Keep terms Korean iOS engineers use in English (SwiftUI, actor, Sendable, retain cycle, …) in English.
  For terms with a common Korean form, use it with the English in parentheses on first use,
  e.g. 동시성(concurrency), 순환 참조(retain cycle).
- Translate our English entry faithfully; don't shorten, omit, add content, or add a translator's note
  (the site shows a translation notice automatically).
- Headings in the Korean version: `## 요약`, `## 핵심 내용`, `## 노트`.
- Existing example: `_articles/2024-09-24-mastering-container-views-in-swiftui-basics.md` and its `ko/` version.

## Keywords

Taxonomy: `_data/keywords.yml`. If `keywords.rb` misses an entry's main topic, add an alias
(English or Korean) to the taxonomy rather than hand-editing keywords.

## Checking the site

```sh
bundle install
bundle exec jekyll build   # or `serve` → http://localhost:4000/ios-articles-archive/
```
