# frozen_string_literal: true

module Rules
  class RuleEngine
    def initialize(gmail_client:)
      @gmail_client = gmail_client
    end

    def process_message!(message:, rules_scope: Rule.active.ordered)
      Array(rules_scope).each do |rule|
        next unless Matcher.new(rule: rule, message: message).matches?

        return apply_for_rule(rule: rule, message: message)
      end

      { matched: false }
    end

    private

    attr_reader :gmail_client

    def apply_for_rule(rule:, message:)
      rule_version = rule.version_digest
      existing = RuleApplication.find_by(
        gmail_message_id: message[:id],
        rule_id: rule.id,
        rule_version: rule_version
      )

      return { matched: true, applied: false, rule_id: rule.id, reason: "already_applied" } if existing

      actions = ActionExecutor.new(rule: rule, message: message, gmail_client: gmail_client).execute!

      RuleApplication.create!(
        gmail_message_id: message[:id],
        rule_id: rule.id,
        rule_version: rule_version,
        result: {
          matched_by: rule.definition["conditions"],
          actions: actions
        },
        applied_at: Time.current
      )

      { matched: true, applied: true, rule_id: rule.id, actions: actions }
    rescue ActiveRecord::RecordNotUnique
      { matched: true, applied: false, rule_id: rule.id, reason: "already_applied" }
    end
  end
end
