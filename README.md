# iOS Articles Archive

An archive of articles and a handbook about iOS engineering, published with GitHub Pages.

**Site:** https://2sem.github.io/ios-articles-archive/

- **Search** by keyword, free text, and date range — all client-side, all in the URL so searches are shareable
  (e.g. `?q=actor&k=Concurrency&from=2025-01-01&to=2025-12-31`).
- **Keywords are assigned automatically** to new entries from a curated iOS taxonomy
  ([`_data/keywords.yml`](_data/keywords.yml)).
- Two collections: dated **articles** (`_articles/`) and evergreen **handbook** pages (`_handbook/`).
- **Every entry not written in Korean gets a Korean translation** archived next to it
  (`_articles/ko/`, `_handbook/ko/`), linked both ways and searchable.
- English and Korean content both work in search and in keyword tagging.

## Search syntax

| Input | Meaning |
| --- | --- |
| `actor reentrancy` | entries containing **both** words (title, keywords, summary, body) |
| `"retain cycle"` | exact phrase |
| `actor -combine` | exclude entries mentioning `combine` |
| keyword chips | narrow to entries tagged with **all** selected keywords |
| From / To, presets | inclusive date range |
| Language | `English` / `한국어`; with **All**, an article and its translation show as one result |
| `/` | focus the search box · `Esc` clears it |

Results are ranked by where terms appear (title > keywords > summary > body); sort by date instead with the Sort menu.

## Adding an article

```sh
ruby scripts/new_article.rb "Understanding Sendable"                   # article, dated today
ruby scripts/new_article.rb "Some post" --source https://example.com/p # archive an external article
ruby scripts/new_article.rb "Release Checklist" --handbook             # handbook page
```

Write the body and `summary`, leave `keywords: []`, and open a pull request.
The **Process entries** workflow adds keywords and, for non-Korean entries, a Korean translation, and commits them to your branch.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the front matter reference and how tagging works.

## Korean translations

`scripts/translate.rb` finds entries that aren't written in Korean and archives a Korean translation of each,
using the Claude API (`claude-opus-5`, with server-side refusal fallbacks enabled):

```sh
ruby scripts/translate.rb --dry-run   # list entries missing a current translation (no API calls)
ANTHROPIC_API_KEY=... bundle exec ruby scripts/translate.rb
```

- A translation lives at `_<collection>/ko/<same file name>` with `lang: ko` and `translation_of: <original>`.
  Keywords are copied from the original by `scripts/keywords.rb`.
- Language is detected from the text (Hangul share of the prose, code excluded) unless `lang` is set in front matter.
- Each translation stores `translation_hash`, a digest of the original's title, summary and body.
  **Editing the original makes the translation stale, and it is re-translated on the next run** —
  so fix wording in the original, not in the translation (or it'll be overwritten).
- CI runs it on pull requests (committing to the branch) and again on deploy as a safety net.
  Add an `ANTHROPIC_API_KEY` **repository secret** to enable it; without one it is skipped.

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
One-time setup: **Settings → Pages → Build and deployment → Source: GitHub Actions**, and add the
`ANTHROPIC_API_KEY` secret under **Settings → Secrets and variables → Actions** for translations.

---

### 한국어 요약

iOS 엔지니어링 아티클 아카이브 + 핸드북입니다. 키워드·본문·기간으로 검색할 수 있고, 새 글을 PR로 올리면
`_data/keywords.yml`의 분류 체계를 기준으로 키워드가 자동 지정됩니다. 한국어 본문도 검색·태깅됩니다
(예: 본문의 "모듈화를" → `Modularization`). 새 주제는 `keywords.yml`에 별칭(한국어 포함)을 추가하면 됩니다.
한국어가 아닌 글은 Claude API로 번역한 한국어판이 `ko/` 폴더에 함께 보관되며, 원문을 수정하면 번역도 다시 생성됩니다
(리포지토리 시크릿 `ANTHROPIC_API_KEY` 필요).
