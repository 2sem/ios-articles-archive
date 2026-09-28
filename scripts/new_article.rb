#!/usr/bin/env ruby
# frozen_string_literal: true

# Scaffolds a new archive entry.
#
#   ruby scripts/new_article.rb "Understanding Sendable"
#   ruby scripts/new_article.rb "Weekly notes" --source https://example.com/post --author "Jane Doe"
#   ruby scripts/new_article.rb "Code Review Checklist" --handbook
#
# Leave `keywords` empty: `ruby scripts/keywords.rb` (and CI on every pull request)
# fills them in from _data/keywords.yml once the body is written.

require "date"
require "fileutils"
require "json"
require "optparse"

options = { kind: "articles", date: Date.today }
OptionParser.new do |o|
  o.banner = "usage: ruby scripts/new_article.rb TITLE [--handbook] [--source URL] [--author NAME] [--date YYYY-MM-DD]"
  o.on("--handbook", "create a handbook page instead of an article") { options[:kind] = "handbook" }
  o.on("--source URL", "original URL when archiving an external article") { |v| options[:source] = v }
  o.on("--author NAME") { |v| options[:author] = v }
  o.on("--date DATE", "publication date (default: today)") { |v| options[:date] = Date.iso8601(v) }
end.parse!

title = ARGV.join(" ").strip
abort "error: a title is required" if title.empty?

slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
abort "error: title must contain latin letters or digits for the file name" if slug.empty?

root = File.expand_path("..", __dir__)
name = options[:kind] == "articles" ? "#{options[:date].iso8601}-#{slug}.md" : "#{slug}.md"
path = File.join(root, "_#{options[:kind]}", name)
abort "error: #{path} already exists" if File.exist?(path)

front = ["---", "title: #{JSON.generate(title)}", "date: #{options[:date].iso8601}"]
front << "author: #{JSON.generate(options[:author])}" if options[:author]
front << "source_url: #{options[:source]}" if options[:source]
front += ["summary: \"\"", "keywords: []", "---", "", "Write here.", ""]

FileUtils.mkdir_p(File.dirname(path))
File.write(path, front.join("\n"), encoding: "UTF-8")
puts "created #{path.delete_prefix("#{root}/")}"
puts "next: write the body + summary, then run `ruby scripts/keywords.rb #{path.delete_prefix("#{root}/")}`"
