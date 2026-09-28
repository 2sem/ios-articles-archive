#!/usr/bin/env ruby
# frozen_string_literal: true

# Tracks the Korean translations archived for entries that aren't written in Korean.
# The translations themselves are written by Claude in a Claude Code session (see CLAUDE.md);
# this script only finds what's missing or stale, and stamps finished translations.
#
#   ruby scripts/translations.rb                   # list entries missing a current translation
#   ruby scripts/translations.rb --check           # same, exit 1 if any (CI)
#   ruby scripts/translations.rb --stamp FILE...   # mark translations as up to date with their originals
#
# Translations live next to their originals, in a `ko/` subfolder with the same file name:
#   _articles/2025-01-22-actor-reentrancy-explained.md
#   _articles/ko/2025-01-22-actor-reentrancy-explained.md
#
# `--stamp` fills in the translation's bookkeeping front matter — `lang: ko`, `translation_of`,
# `translation_hash` (a digest of the original's title, summary and body), plus `date`, `author`
# and `source_url` copied from the original. When the original changes later, the hash no longer
# matches and the translation is reported as stale. Keywords are copied by scripts/keywords.rb.

require "date"
require "digest"
require "json"
require "optparse"
require "yaml"

ROOT = File.expand_path("..", __dir__)
COLLECTION_DIRS = %w[_articles _handbook].freeze
TRANSLATION_DIR = "ko"
FRONT_MATTER = /\A---\s*\n(.*?\n?)^---\s*$\n?/m
HANGUL = /[ㄱ-ㆎ가-힣]/
LATIN = /[A-Za-z]/

def rel(path) = path.delete_prefix("#{ROOT}/")

Entry = Struct.new(:path, :raw, :front_matter, :data, :body, keyword_init: true) do
  def self.load(path)
    raw = File.read(path, encoding: "UTF-8")
    match = raw.match(FRONT_MATTER) or abort "error: #{rel(path)} has no YAML front matter"
    data = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
    new(path: path, raw: raw, front_matter: match[1], data: data, body: match.post_match)
  end

  def translation? = File.basename(File.dirname(path)) == TRANSLATION_DIR
  def translation_path = File.join(File.dirname(path), TRANSLATION_DIR, File.basename(path))
  def original_path = File.join(File.dirname(path, 2), File.basename(path))

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

  # Sets front matter keys (replacing existing ones), keeping everything else as written.
  def write_front_matter!(values)
    lines = front_matter.lines
    values.each do |key, value|
      line = "#{key}: #{value}\n"
      index = lines.index { |l| l.start_with?("#{key}:") }
      if index
        lines[index] = line
      else
        lines << "\n" unless lines.empty? || lines.last.end_with?("\n")
        lines << line
      end
    end
    File.write(path, raw.sub(front_matter) { lines.join }, encoding: "UTF-8")
  end
end

def yaml_string(value) = JSON.generate(value.to_s) # JSON strings are valid YAML scalars

def stamp(path)
  path = Entry.load(path).translation_path unless Entry.load(path).translation?
  abort "error: #{rel(path)} does not exist — write the translation first" unless File.exist?(path)

  translation = Entry.load(path)
  original_path = translation.original_path
  abort "error: original #{rel(original_path)} not found" unless File.exist?(original_path)
  original = Entry.load(original_path)

  values = { "date" => original.data["date"].to_s }
  values["author"] = yaml_string(original.data["author"]) if original.data["author"]
  values["source_url"] = original.data["source_url"] if original.data["source_url"]
  values.merge!(
    "lang" => "ko",
    "translation_of" => rel(original_path),
    "translation_hash" => original.content_hash
  )
  translation.write_front_matter!(values)
  puts "stamped #{rel(path)} (translation of #{rel(original_path)})"
end

def status(entry)
  return "missing" unless File.exist?(entry.translation_path)

  "stale — original changed" if Entry.load(entry.translation_path).data["translation_hash"] != entry.content_hash
end

options = { check: false, stamp: false }
OptionParser.new do |o|
  o.banner = "usage: ruby scripts/translations.rb [--check] | --stamp FILE..."
  o.on("--check", "exit 1 if any entry lacks a current Korean translation") { options[:check] = true }
  o.on("--stamp", "mark the given translations (or originals' translations) as current") { options[:stamp] = true }
end.parse!

if options[:stamp]
  abort "error: --stamp needs at least one file" if ARGV.empty?
  ARGV.each { |f| stamp(File.expand_path(f)) }
  exit 0
end

files = COLLECTION_DIRS.flat_map { |d| Dir.glob(File.join(ROOT, d, "**", "*.md")) }.sort
entries = files.map { |f| Entry.load(f) }

orphans = entries.select(&:translation?).reject { |e| File.exist?(e.original_path) }
orphans.each { |e| puts "#{rel(e.path)}: translation of a missing original — delete it or fix the file name" }

pending = entries.reject(&:translation?).reject(&:korean?).filter_map do |entry|
  reason = status(entry)
  [entry, reason] if reason
end
pending.each do |entry, reason|
  puts "#{rel(entry.path)}: Korean translation #{reason} (#{rel(entry.translation_path)})"
end

if pending.empty? && orphans.empty?
  puts "All entries have a current Korean translation."
  exit 0
end

if options[:check]
  puts
  puts "Ask Claude Code to translate them (see CLAUDE.md), then run:"
  puts "  ruby scripts/translations.rb --stamp #{pending.map { |e, _| rel(e.translation_path) }.join(' ')}".rstrip
  exit 1
end
