# frozen_string_literal: true

module MailListener
  class CycleProcessor
    DEFAULT_QUERY = "in:inbox"

    def initialize(dry_run: false, gmail_client: Gmail::Client.new)
      @dry_run = dry_run
      @gmail_client = gmail_client
    end

    def process!
      forward_result = Rules::AutoRulesCreator.new(gmail_client: gmail_client, dry_run: dry_run?).process!

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

    private

    attr_reader :gmail_client

    def dry_run?
      @dry_run
    end

    def primary_query
      ENV.fetch("GMAIL_PRIMARY_QUERY", DEFAULT_QUERY)
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
