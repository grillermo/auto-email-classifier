#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

PROJECT_ROOT = File.expand_path("..", __dir__)
RULES_EDITOR_ROOT = File.join(PROJECT_ROOT, "rules_editor")

options = { dry_run: false }

begin
  OptionParser.new do |parser|
    parser.banner = "Usage: bundle exec ruby mail_listener/listener.rb [--dry-run]"
    parser.on("--dry-run", "Print what matching rules would do without applying them") do
      options[:dry_run] = true
    end
  end.parse!(ARGV)
rescue OptionParser::ParseError => e
  abort "[listener] #{e.message}"
end

abort "[listener] Unknown arguments: #{ARGV.join(' ')}" if ARGV.any?

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.1")
  abort "[listener] Ruby #{RUBY_VERSION} detected. Use Ruby 3.4+."
end

begin
  require File.join(RULES_EDITOR_ROOT, "config", "environment")
rescue StandardError => e
  abort "[listener] Failed to load Rails environment: #{e.message}. Run bundle install in #{RULES_EDITOR_ROOT}."
end

module MailListener
  class Runner
    DEFAULT_QUERY = "in:inbox"

    def initialize(dry_run: false)
      @shutdown = false
      @dry_run = dry_run
      @interval = ENV.fetch("GMAIL_POLL_INTERVAL_SECONDS", "60").to_i
      @interval = 60 if @interval <= 0
    end

    def run
      install_signal_handlers
      puts "[listener] started (interval=#{@interval}s, mode=#{dry_run? ? "dry-run" : "live"})"

      until @shutdown
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        process_cycle
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

        sleep_for = @interval - elapsed
        break if @shutdown

        sleep([sleep_for, 1].max)
      end

      puts "[listener] stopped"
    end

    private

    def dry_run?
      @dry_run
    end

    def process_cycle
      gmail_client = Gmail::Client.new
      forward_result = Rules::ForwardedRuleProcessor.new(gmail_client: gmail_client, dry_run: dry_run?).process!

      rules = Rule.active.ordered.to_a
      message_ids = gmail_client.list_message_ids(query: primary_query, max_results: 500)

      puts "[listener] cycle: mode=#{dry_run? ? "dry-run" : "live"}, messages=#{message_ids.length}, active_rules=#{rules.length}, auto_created=#{forward_result[:created]}"

      engine = Rules::RuleEngine.new(gmail_client: gmail_client, dry_run: dry_run?)

      message_ids.each do |message_id|
        message = gmail_client.fetch_normalized_message(message_id)
        result = engine.process_message!(message: message, rules_scope: rules)

        next unless result[:matched]

        log_rule_result(message_id: message_id, result: result)
      end
    rescue StandardError => e
      puts "[listener] cycle failed: #{e.class} #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end

    def primary_query
      ENV.fetch("GMAIL_PRIMARY_QUERY", DEFAULT_QUERY)
    end

    def install_signal_handlers
      %w[INT TERM].each do |signal|
        Signal.trap(signal) { @shutdown = true }
      end
    end

    def log_rule_result(message_id:, result:)
      parts = ["[listener] message=#{message_id}", "matched", "rule=#{result[:rule_id]}"]
      parts << "name=#{result[:rule_name].inspect}" if result[:rule_name]

      if result[:dry_run]
        parts << "dry_run=true"
        parts << "would_apply=#{result[:would_apply]}"
      else
        parts << "applied=#{result[:applied]}"
      end

      parts << "reason=#{result[:reason]}" if result[:reason]
      parts << "actions=#{format_actions(result[:actions])}" unless Array(result[:actions]).empty?

      puts parts.join(" ")
    end

    def format_actions(actions)
      Array(actions).map do |action|
        label = action[:label]
        label ? "#{action[:type]}(#{label})" : action[:type]
      end.join(",")
    end
  end
end

MailListener::Runner.new(dry_run: options[:dry_run]).run
