# iOS Articles Archive

An archive of articles and a handbook about iOS engineering, published with GitHub Pages.

**Site:** https://2sem.github.io/ios-articles-archive/

- **Search** by keyword, free text, and date range — all client-side, all in the URL so searches are shareable
  (e.g. `?q=actor&k=Concurrency&from=2025-01-01&to=2025-12-31`).
- **Keywords are assigned automatically** to new entries from a curated iOS taxonomy
  ([`_data/keywords.yml`](_data/keywords.yml)).
- Two collections: dated **articles** (`_articles/`) and evergreen **handbook** pages (`_handbook/`).
- **Every entry not written in Korean gets a Korean version** archived next to it
  (`_articles/ko/`, `_handbook/ko/`), searchable in either language.
- **EN / KO toggle** in the header switches the content you're viewing: an article flips to its other
  version, and lists and search results show each entry in the chosen language. Entries without a
  Korean version always show in their original language (KO is disabled on those pages).
  The choice is remembered; Korean-locale browsers start in KO.
- English and Korean content both work in search and in keyword tagging.

## Search syntax

| Input | Meaning |
| --- | --- |
| `actor reentrancy` | entries containing **both** words (title, keywords, summary, body) |
| `"retain cycle"` | exact phrase |
| `actor -combine` | exclude entries mentioning `combine` |
| keyword chips | narrow to entries tagged with **all** selected keywords |
| From / To, presets | inclusive date range |
| `/` | focus the search box · `Esc` clears it |

Results are ranked by where terms appear (title > keywords > summary > body); sort by date instead with the Sort menu.

## Adding an article

```sh
ruby scripts/new_article.rb "Understanding Sendable"                   # article, dated today
ruby scripts/new_article.rb "Some post" --source https://example.com/p # archive an external article
ruby scripts/new_article.rb "Release Checklist" --handbook             # handbook page
```

Write a summary of the article (format in [`CLAUDE.md`](CLAUDE.md)) with its `summary` field, leave `keywords: []`, and open a pull request.
The **Process entries** workflow adds keywords (committed to your branch) and checks that non-Korean entries have a Korean translation.
Easiest: ask Claude Code to add the article — [`CLAUDE.md`](CLAUDE.md) has it write the translation and keywords too.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the front matter reference and how tagging works.

## Korean translations

Every entry not written in Korean has a Korean translation at `_<collection>/ko/<same file name>`
(`lang: ko`, `translation_of: <original>`), linked both ways on the site.

Translations are written with **Claude Code** when an entry is added — no API key or paid API.
[`CLAUDE.md`](CLAUDE.md) tells any Claude Code session how: write the translation, stamp it, assign keywords.
Just ask Claude Code to "add this article" and it follows those steps.

```sh
ruby scripts/translations.rb                   # list entries missing a current translation
ruby scripts/translations.rb --stamp FILE...   # mark a finished translation as current
ruby scripts/translations.rb --check           # exit 1 if any are missing or stale (CI)
```

- Each translation stores `translation_hash`, a digest of the original's title, summary and body.
  **Editing the original marks the translation stale** until it's updated and stamped again.
- Language is detected from the text (Hangul share of the prose, code excluded) unless `lang` is set.
- Pull requests fail the **Process entries** check while a translation is missing or stale; deploys only warn.

## How keywords are assigned

`scripts/keywords.rb` scores every topic in `_data/keywords.yml` against an entry — each alias hit counts
×3 in the title, ×2 in the summary, ×1 in the body — and keeps topics scoring at least 3 (up to 6).
Hand-written keywords are kept and normalized to canonical names (`async/await` → `Concurrency`, `spm` → `Swift Package Manager`).

```sh
ruby scripts/keywords.rb            # tag entries without keywords, normalize the rest
ruby scripts/keywords.rb --dry-run  # preview
ruby scripts/keywords.rb --check    # exit 1 if anything would change (CI)
ruby scripts/keywords.rb --force    # re-score entries that already have keywords
```

To teach the tagger a new topic, add it to `_data/keywords.yml` — no code changes.

## Local development

```sh
bundle install
bundle exec jekyll serve   # http://localhost:4000/ios-articles-archive/
```

## Deployment

Pushes to `main` build and deploy via [`.github/workflows/pages.yml`](.github/workflows/pages.yml).
One-time setup: **Settings → Pages → Build and deployment → Source: GitHub Actions**.

---

### 한국어 요약

iOS 엔지니어링 아티클 아카이브 + 핸드북입니다. 키워드·본문·기간으로 검색할 수 있고, 새 글을 PR로 올리면
`_data/keywords.yml`의 분류 체계를 기준으로 키워드가 자동 지정됩니다. 한국어 본문도 검색·태깅됩니다
(예: 본문의 "모듈화를" → `Modularization`). 새 주제는 `keywords.yml`에 별칭(한국어 포함)을 추가하면 됩니다.
한국어가 아닌 글은 한국어 번역본이 `ko/` 폴더에 함께 보관됩니다. 번역은 API 없이 Claude Code 세션에서 글을 추가할 때
함께 작성하며(`CLAUDE.md` 참고), 원문을 수정하면 CI가 번역이 오래되었다고 알려 줍니다.
