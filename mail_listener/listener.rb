#!/usr/bin/env ruby
# frozen_string_literal: true

PROJECT_ROOT = File.expand_path("..", __dir__)
RULES_EDITOR_ROOT = File.join(PROJECT_ROOT, "rules_editor")

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
    DEFAULT_QUERY = "is:unread in:inbox"

    def initialize
      @shutdown = false
      @interval = ENV.fetch("GMAIL_POLL_INTERVAL_SECONDS", "60").to_i
      @interval = 60 if @interval <= 0
    end

    def run
      install_signal_handlers
      puts "[listener] started (interval=#{@interval}s)"

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

    def process_cycle
      gmail_client = Gmail::Client.new
      forward_result = Rules::ForwardedRuleProcessor.new(gmail_client: gmail_client).process!

      rules = Rule.active.ordered.to_a
      message_ids = gmail_client.list_message_ids(query: primary_query, max_results: 500)

      puts "[listener] cycle: messages=#{message_ids.length}, active_rules=#{rules.length}, auto_created=#{forward_result[:created]}"

      engine = Rules::RuleEngine.new(gmail_client: gmail_client)

      message_ids.each do |message_id|
        message = gmail_client.fetch_normalized_message(message_id)
        result = engine.process_message!(message: message, rules_scope: rules)

        next unless result[:matched]

        puts "[listener] message=#{message_id} matched rule=#{result[:rule_id]} applied=#{result[:applied]}"
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
  end
end

MailListener::Runner.new.run
