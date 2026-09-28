# Contributing

## 1. Create the file

```sh
ruby scripts/new_article.rb "Your Title"              # → _articles/YYYY-MM-DD-your-title.md
ruby scripts/new_article.rb "Your Title" --handbook   # → _handbook/your-title.md
```

Or create it by hand. Articles are named `YYYY-MM-DD-slug.md`; handbook pages `slug.md`.

## 2. Front matter

```yaml
---
title: "Actor Reentrancy, Explained"
date: 2025-01-22            # publication date (handbook: last meaningful revision)
summary: "One or two sentences. Shown in results and weighted in search. Markdown `code` is fine."
author: "Jane Doe"          # optional
source_url: https://…       # optional — set when archiving an article published elsewhere
keywords: []                # leave empty; filled in automatically
---
```

Only archive external articles you have the right to republish; otherwise write a summary with your own notes and link to the original via `source_url`.

## 3. Keywords

Leave `keywords` empty and open a pull request — the **Process entries** workflow assigns them and commits to your branch.
(From a fork, run `ruby scripts/keywords.rb` yourself; the workflow checks it.)

You may also set keywords by hand. They are normalized to the taxonomy's canonical names;
keywords outside `_data/keywords.yml` are kept but produce a warning — prefer adding the topic (or an alias) to the taxonomy.

**Good keywords** describe what a reader would search for: the main topic first, then at most a few secondary topics.
If the tagger misses the main topic, the fix is usually a missing alias in `_data/keywords.yml`.

## 4. Korean translation

Every entry not written in Korean needs a Korean translation at `ko/<same file name>`.
The easy way: ask Claude Code to add the article — [`CLAUDE.md`](CLAUDE.md) has it write the translation,
following the translation rules there. To do it by hand, write `title`, `summary` and the body, then:

```sh
ruby scripts/translations.rb --stamp _articles/ko/<file name>.md
ruby scripts/keywords.rb
```

If you edit an original later, update its translation and stamp it again — CI fails while it's stale.
For a Korean-language entry, add `lang: ko` to the front matter (it's also detected automatically).

## 5. Preview

```sh
bundle exec jekyll serve
```
