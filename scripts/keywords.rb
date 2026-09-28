#!/usr/bin/env ruby
# frozen_string_literal: true

# Assigns and normalizes keywords for archive entries using _data/keywords.yml.
#
#   ruby scripts/keywords.rb                 # tag every entry that has no keywords, normalize the rest
#   ruby scripts/keywords.rb FILE...         # only these files
#   ruby scripts/keywords.rb --check         # CI mode: exit 1 if any file would change
#   ruby scripts/keywords.rb --dry-run       # print what would change, write nothing
#   ruby scripts/keywords.rb --force         # re-score entries that already have keywords (merges)
#
# Rules:
#   * Entries with no `keywords` get the best-scoring taxonomy topics
#     (title x3, summary x2, body x1; at most MAX_KEYWORDS).
#   * Translations (`ko/` subfolders, see scripts/translations.rb) copy their original's keywords.
#   * Existing keywords are normalized to canonical names ("async/await" -> "Concurrency").
#     Keywords not in the taxonomy are kept as-is, with a warning.

require "json"
require "optparse"
require "yaml"
require "date"

ROOT = File.expand_path("..", __dir__)
TAXONOMY_PATH = File.join(ROOT, "_data", "keywords.yml")
COLLECTION_DIRS = %w[_articles _handbook].freeze
FRONT_MATTER = /\A---\s*\n(.*?\n?)^---\s*$\n?/m

MAX_KEYWORDS = 6
MIN_SCORE = 3
WEIGHTS = { title: 3, summary: 2, body: 1 }.freeze
MAX_HITS_PER_ALIAS = 5 # one alias repeated 40 times shouldn't dominate

Topic = Struct.new(:name, :patterns, :lookup_keys)

def load_taxonomy
  YAML.safe_load(File.read(TAXONOMY_PATH, encoding: "UTF-8")).map do |entry|
    name = entry.fetch("name")
    aliases = [name, *entry.fetch("aliases", [])].map(&:to_s).uniq
    patterns = aliases.map { |a| alias_pattern(a, case_sensitive: a != name && identifier?(a)) }
    Topic.new(name, patterns, aliases.map(&:downcase))
  end
end

# Single-word aliases with an uppercase letter are code identifiers (`Task`, `DI`, `UIView`);
# matching them case-sensitively keeps prose like "a task" or "di-" from counting.
def identifier?(text)
  !text.match?(/\s/) && text.match?(/[A-Z]/)
end

def alias_pattern(text, case_sensitive:)
  escaped = Regexp.escape(text).gsub("\\ ", "[\\s-]+")
  # \b fails next to symbols such as "@State" or "#Preview", so assert non-word neighbours instead.
  source = "(?<![\\w@#])#{escaped}(?![\\w])"
  Regexp.new(source, case_sensitive ? nil : Regexp::IGNORECASE)
end

def count_hits(topic, text)
  topic.patterns.sum { |re| [text.scan(re).size, MAX_HITS_PER_ALIAS].min }
end

def score(topics, title:, summary:, body:)
  topics.filter_map do |topic|
    total = WEIGHTS[:title] * count_hits(topic, title) +
            WEIGHTS[:summary] * count_hits(topic, summary) +
            WEIGHTS[:body] * count_hits(topic, body)
    [topic.name, total] if total.positive?
  end.sort_by { |name, total| [-total, name] }
end

def suggest(topics, **text)
  ranked = score(topics, **text)
  picked = ranked.select { |_, total| total >= MIN_SCORE }.first(MAX_KEYWORDS).map(&:first)
  picked = ranked.first(1).map(&:first) if picked.empty? # short entries: best guess beats nothing
  picked
end

def normalize(topics, keywords, file)
  keywords.map do |kw|
    key = kw.to_s.strip.downcase
    topic = topics.find { |t| t.lookup_keys.include?(key) }
    warn "  warning: #{rel(file)}: \"#{kw}\" is not in _data/keywords.yml (kept as-is)" unless topic
    topic ? topic.name : kw.to_s.strip
  end.reject(&:empty?).uniq
end

def rewrite_keywords(front_matter, keywords)
  line = "keywords: [#{keywords.map(&:to_json).join(", ")}]"
  lines = front_matter.lines
  start = lines.index { |l| l.match?(/\Akeywords\s*:/) }
  if start
    stop = start + 1
    stop += 1 while stop < lines.size && lines[stop].match?(/\A(\s+\S|\s*-\s)/)
    lines[start...stop] = ["#{line}\n"]
  else
    lines << "\n" unless lines.empty? || lines.last.end_with?("\n")
    lines << "#{line}\n"
  end
  lines.join
end

def rel(path) = path.delete_prefix("#{ROOT}/")

def translation?(file) = File.basename(File.dirname(file)) == "ko"
def original_of(file) = File.join(File.dirname(file, 2), File.basename(file))

def read_keywords(file)
  match = File.read(file, encoding: "UTF-8").match(FRONT_MATTER)
  data = match && YAML.safe_load(match[1], permitted_classes: [Date, Time])
  Array(data && data["keywords"]).map(&:to_s)
end

def process(file, topics, force:, inherited: nil)
  raw = File.read(file, encoding: "UTF-8")
  match = raw.match(FRONT_MATTER)
  abort "error: #{rel(file)} has no YAML front matter" unless match

  data = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
  body = match.post_match
  existing = Array(data["keywords"]).map(&:to_s).reject { |k| k.strip.empty? }

  keywords = inherited || normalize(topics, existing, file)
  if inherited.nil? && (keywords.empty? || force)
    suggested = suggest(topics, title: data["title"].to_s, summary: data["summary"].to_s, body: body)
    keywords = (keywords + suggested).uniq.first([MAX_KEYWORDS, keywords.size].max)
  end
  warn "  warning: #{rel(file)}: no keyword matched — add one by hand" if keywords.empty?

  return nil if keywords == existing

  updated = raw[0...match.begin(1)] + rewrite_keywords(match[1], keywords) + raw[match.end(1)..]
  [updated, existing, keywords]
end

options = { check: false, dry_run: false, force: false }
OptionParser.new do |o|
  o.banner = "usage: ruby scripts/keywords.rb [--check|--dry-run] [--force] [FILE...]"
  o.on("--check", "exit 1 if any file needs keyword changes") { options[:check] = true }
  o.on("--dry-run", "show changes without writing") { options[:dry_run] = true }
  o.on("--force", "re-score entries that already have keywords") { options[:force] = true }
end.parse!

files = if ARGV.empty?
          COLLECTION_DIRS.flat_map { |d| Dir.glob(File.join(ROOT, d, "**", "*.md")) }.sort
        else
          ARGV.map { |f| File.expand_path(f) }.select { |f| File.file?(f) && f.end_with?(".md") }
        end

topics = load_taxonomy
changed = 0
resolved = {} # original path => its final keywords, handed down to translations
files.partition { |f| !translation?(f) }.flatten.each do |file|
  inherited = nil
  if translation?(file)
    original = original_of(file)
    inherited = resolved[original] || (read_keywords(original) if File.exist?(original))
    warn "  warning: #{rel(file)}: original #{rel(original)} not found" unless inherited
  end

  result = process(file, topics, force: options[:force], inherited: inherited)
  resolved[file] = result ? result.last : read_keywords(file)
  next unless result

  updated, before, after = result
  changed += 1
  puts "#{rel(file)}: #{before.empty? ? '(none)' : before.join(', ')} -> #{after.join(', ')}"
  File.write(file, updated, encoding: "UTF-8") unless options[:check] || options[:dry_run]
end

puts "#{changed} of #{files.size} file(s) #{options[:check] || options[:dry_run] ? 'need' : 'got'} keyword updates."
exit(1) if options[:check] && changed.positive?
