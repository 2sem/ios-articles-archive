#!/usr/bin/env ruby
# frozen_string_literal: true

# Archives a Korean translation of every entry that isn't written in Korean.
#
#   ruby scripts/translate.rb              # translate new entries, re-translate changed ones
#   ruby scripts/translate.rb FILE...      # only these originals
#   ruby scripts/translate.rb --dry-run    # list what would be translated; no API calls
#   ruby scripts/translate.rb --force      # re-translate even if the translation is current
#
# Translations live next to their originals, in a `ko/` subfolder with the same file name:
#   _articles/2025-01-22-actor-reentrancy-explained.md
#   _articles/ko/2025-01-22-actor-reentrancy-explained.md
#
# Each translation records `translation_hash`, a digest of the original's title, summary and
# body. When the original changes, the hash no longer matches and the entry is re-translated.
# Keywords are copied from the original by scripts/keywords.rb, so run that afterwards.
#
# Requires ANTHROPIC_API_KEY (or another credential source the Anthropic SDK understands).
# Without one, the script lists pending work and exits 0 so CI doesn't fail on forks.

require "date"
require "digest"
require "json"
require "optparse"
require "yaml"

ROOT = File.expand_path("..", __dir__)
COLLECTION_DIRS = %w[_articles _handbook].freeze
TRANSLATION_DIR = "ko"
FRONT_MATTER = /\A---\s*\n(.*?\n?)^---\s*$\n?/m
MODEL = "claude-opus-5"
HANGUL = /[ㄱ-ㆎ가-힣]/
LATIN = /[A-Za-z]/

SYSTEM_PROMPT = <<~PROMPT
  You translate iOS engineering articles from English (or another language) into Korean for
  Korean iOS engineers. The result is archived next to the original on a technical blog.

  - Write natural Korean in the 합니다체 style used by Korean tech blogs, not a word-for-word rendering.
  - Keep the Markdown structure exactly: headings, lists, tables, emphasis, links, and images.
  - Copy fenced code blocks and inline code verbatim. Do not translate identifiers, API names,
    or code comments inside code blocks.
  - Keep established technical terms in English where Korean engineers use them in English
    (SwiftUI, actor, Sendable, retain cycle, ...). For terms with a common Korean form, use it
    and add the English in parentheses on first use, e.g. 동시성(concurrency).
  - Translate everything else. Do not summarize, omit, or add content, and do not add a
    translator's note.
PROMPT

OUTPUT_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string", description: "Translated title" },
    summary: { type: "string", description: "Translated summary; empty string if the original has none" },
    body: { type: "string", description: "Translated Markdown body" }
  },
  required: %w[title summary body],
  additionalProperties: false
}.freeze

Entry = Struct.new(:path, :raw, :front_matter, :data, :body, keyword_init: true) do
  def self.load(path)
    raw = File.read(path, encoding: "UTF-8")
    match = raw.match(FRONT_MATTER) or abort "error: #{rel(path)} has no YAML front matter"
    data = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
    new(path: path, raw: raw, front_matter: match[1], data: data, body: match.post_match)
  end

  def translation? = File.basename(File.dirname(path)) == TRANSLATION_DIR

  def translation_path
    File.join(File.dirname(path), TRANSLATION_DIR, File.basename(path))
  end

  # Korean if declared, or if Hangul dominates the prose (code blocks and inline code excluded).
  def korean?
    return data["lang"].to_s.start_with?("ko") if data["lang"]

    prose = [data["title"], data["summary"], body].join("\n")
                                                   .gsub(/^```.*?^```/m, "")
                                                   .gsub(/`[^`]*`/, "")
    hangul = prose.scan(HANGUL).size
    latin = prose.scan(LATIN).size
    hangul.positive? && hangul >= (hangul + latin) * 0.2
  end

  def content_hash
    Digest::SHA256.hexdigest([data["title"], data["summary"], body].map(&:to_s).join("\u0000"))[0, 16]
  end
end

def rel(path) = path.delete_prefix("#{ROOT}/")

def yaml_string(value) = JSON.generate(value.to_s) # JSON strings are valid YAML scalars

# Records `lang: ko` on Korean originals that don't declare it, so the site can label them.
def declare_korean!(entry)
  return if entry.data["lang"]

  lines = entry.front_matter.lines
  lines << "\n" unless lines.empty? || lines.last.end_with?("\n")
  lines << "lang: ko\n"
  File.write(entry.path, entry.raw.sub(entry.front_matter) { lines.join }, encoding: "UTF-8")
  puts "#{rel(entry.path)}: written in Korean — added lang: ko"
end

def pending_reason(entry, force:)
  return "new" unless File.exist?(entry.translation_path)
  return "forced" if force

  existing = Entry.load(entry.translation_path)
  "original changed" if existing.data["translation_hash"] != entry.content_hash
end

def translate(client, entry)
  source = +""
  source << "Title: #{entry.data['title']}\n"
  source << "Summary: #{entry.data['summary']}\n" unless entry.data["summary"].to_s.strip.empty?
  source << "\n---BODY---\n#{entry.body}"

  stream = client.beta.messages.stream(
    model: MODEL,
    max_tokens: 64_000,
    system_: SYSTEM_PROMPT,
    output_config: { format_: { type: :json_schema, schema: OUTPUT_SCHEMA } },
    # Retry on Anthropic's recommended substitute model if a safety classifier declines.
    fallbacks: :default,
    betas: ["server-side-fallback-2026-07-01"],
    messages: [{ role: "user", content: "Translate this article into Korean.\n\n#{source}" }]
  )
  message = stream.accumulated_message

  case message.stop_reason
  when :refusal
    raise "declined by the model (#{message.stop_details&.category || 'no category'})"
  when :max_tokens
    raise "translation was cut off at max_tokens"
  end

  text = message.content.select { |block| block.type == :text }.map(&:text).join
  JSON.parse(text)
end

def write_translation(entry, result)
  original = entry.data
  front = ["---", "title: #{yaml_string(result['title'])}", "date: #{original['date']}"]
  front << "author: #{yaml_string(original['author'])}" if original["author"]
  front << "source_url: #{original['source_url']}" if original["source_url"]
  front << "summary: #{yaml_string(result['summary'])}" unless result["summary"].to_s.strip.empty?
  front += [
    "lang: ko",
    "translation_of: #{rel(entry.path)}",
    "translation_hash: #{entry.content_hash}",
    "keywords: [#{Array(original['keywords']).map(&:to_json).join(', ')}]",
    "---",
    ""
  ]
  body = result["body"].to_s.sub(/\A\s*---BODY---\s*/, "")
  body += "\n" unless body.end_with?("\n")

  FileUtils.mkdir_p(File.dirname(entry.translation_path))
  File.write(entry.translation_path, "#{front.join("\n")}\n#{body}", encoding: "UTF-8")
end

options = { dry_run: false, force: false }
OptionParser.new do |o|
  o.banner = "usage: ruby scripts/translate.rb [--dry-run] [--force] [FILE...]"
  o.on("--dry-run", "list entries that need a translation; no API calls") { options[:dry_run] = true }
  o.on("--force", "re-translate even when the translation is current") { options[:force] = true }
end.parse!

files = if ARGV.empty?
          COLLECTION_DIRS.flat_map { |d| Dir.glob(File.join(ROOT, d, "**", "*.md")) }.sort
        else
          ARGV.map { |f| File.expand_path(f) }.select { |f| File.file?(f) && f.end_with?(".md") }
        end

entries = files.map { |f| Entry.load(f) }.reject(&:translation?)
entries.select(&:korean?).each { |e| declare_korean!(e) unless options[:dry_run] }

pending = entries.reject(&:korean?).filter_map do |entry|
  reason = pending_reason(entry, force: options[:force])
  [entry, reason] if reason
end

pending.each { |entry, reason| puts "#{rel(entry.path)}: needs Korean translation (#{reason})" }
if pending.empty?
  puts "All #{entries.size} entries have a current Korean version."
  exit 0
end
exit 0 if options[:dry_run]

credentials = %w[ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_PROFILE].any? { |k| ENV[k].to_s != "" }
unless credentials
  warn "warning: ANTHROPIC_API_KEY is not set — skipped #{pending.size} translation(s)."
  exit 0
end

require "anthropic"
require "fileutils"

client = Anthropic::Client.new
failures = 0
pending.each do |entry, _|
  print "translating #{rel(entry.path)} … "
  write_translation(entry, translate(client, entry))
  puts "→ #{rel(entry.translation_path)}"
rescue Anthropic::Errors::RateLimitError, Anthropic::Errors::APIConnectionError => e
  failures += 1
  puts "failed (#{e.class.name.split('::').last}; will retry on the next run)"
rescue Anthropic::Errors::APIStatusError, JSON::ParserError, RuntimeError => e
  failures += 1
  puts "failed: #{e.message}"
end

exit(failures.positive? ? 1 : 0)
