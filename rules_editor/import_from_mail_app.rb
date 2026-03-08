#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "uri"

require_relative "config/environment"

class MailAppImporter
  ALL_EMAIL_MAILBOX = ["[Gmail]/All Mail"].freeze

  def initialize(plist_path)
    @plist_path = File.expand_path(plist_path)
  end

  def run!
    parsed = parse_plist
    next_priority = Rule.maximum(:priority).to_i + 1
    imported = 0
    skipped = 0

    parsed.each do |raw_rule|
      transformed = transform_rule(raw_rule)

      if transformed[:definition][:conditions].empty? || transformed[:definition][:actions].empty?
        skipped += 1
        puts "Skipping rule '#{raw_rule['RuleName']}' because it has no supported conditions/actions"
        next
      end

      source_rule_id = transformed[:metadata][:source_rule_id].to_s
      rule = if source_rule_id.empty?
               Rule.new
             else
               Rule.find_by("metadata ->> 'source_rule_id' = ?", source_rule_id) || Rule.new
             end

      rule.assign_attributes(
        name: transformed[:name],
        active: true,
        priority: rule.new_record? ? next_priority : rule.priority,
        definition: transformed[:definition],
        metadata: transformed[:metadata]
      )

      # rule.save!

      next_priority += 1 if rule.previous_changes.key?("id")
      imported += 1
    rescue StandardError => e
      skipped += 1
      puts "Failed to import '#{raw_rule['RuleName']}': #{e.class} #{e.message}"
    end

    puts "Import complete: imported=#{imported}, skipped=#{skipped}"
  end

  private

  attr_reader :plist_path

  def parse_plist
    raise "Plist file does not exist: #{plist_path}" unless File.exist?(plist_path)

    cmd = ["plutil", "-convert", "json", "-o", "-", plist_path]
    stdout, stderr, status = Open3.capture3(*cmd)

    raise "plutil failed: #{stderr}" unless status.success?

    JSON.parse(stdout)
  end

  def transform_rule(raw_rule)
    actions = build_actions(raw_rule)

    {
      name: raw_rule.fetch("RuleName", "Imported Rule"),
      definition: {
        match_mode: raw_rule["AllCriteriaMustBeSatisfied"] ? "all" : "any",
        conditions: build_conditions(raw_rule["Criteria"]),
        actions: actions
      },
      metadata: {
        source: "mail_app_import",
        source_rule_id: raw_rule["RuleId"],
        source_rule_name: raw_rule["RuleName"],
        raw_flags: {
          deletes: raw_rule["Deletes"],
          mark_read: raw_rule["MarkRead"],
          should_transfer_message: raw_rule["ShouldTransferMessage"],
          should_copy_message: raw_rule["ShouldCopyMessage"],
          mailbox_url: raw_rule["MailboxURL"],
          copy_to_mailbox_url: raw_rule["CopyToMailboxURL"]
        },
      }
    }
  end

  def build_conditions(raw_conditions)
    Array(raw_conditions).filter_map do |condition|
      field = map_header(condition["Header"])
      next if field.nil?

      value = condition["Expression"].to_s.strip
      next if value.empty?

      {
        field: field,
        operator: condition["Qualifier"] == "IsEqualTo" ? "exact" : "contains",
        value: value,
        case_sensitive: false
      }
    end
  end

  def build_actions(raw_rule)
    actions = []

    actions << { type: "trash" } if raw_rule["Deletes"]
    actions << { type: "mark_read" } if raw_rule["MarkRead"]

    label = label_from_mailbox_url(raw_rule["CopyToMailboxURL"])

    if raw_rule["ShouldTransferMessage"]
      actions << { type: "remove_label", label: 'INBOX' }

      actions << { type: "add_label", label: label }
    elsif raw_rule["ShouldCopyMessage"]
      actions << { type: "add_label", label: label }
    end

    puts "actions",actions
    puts "raw_rule",raw_rule
    puts "\n"
    puts "\n"

    actions
  end

  def label_from_mailbox_url(mailbox_url)
    return nil if mailbox_url.to_s.empty?

    uri = URI.parse(mailbox_url)
    decoded_path = URI.decode_www_form_component(uri.path.to_s.sub(%r{^/}, ""))
    decoded_path = decoded_path.gsub(%r{\A/+}, "")
    return nil if decoded_path.empty?

    decoded_path
  rescue URI::InvalidURIError
    nil
  end

  def map_header(header)
    case header.to_s.downcase
    when "from"
      "sender"
    when "subject"
      "subject"
    when "body"
      "body"
    else
      nil
    end
  end
end

default_plist = File.expand_path("../SyncedRules.plist", __dir__)
plist_path = ARGV[0] || default_plist

MailAppImporter.new(plist_path).run!
