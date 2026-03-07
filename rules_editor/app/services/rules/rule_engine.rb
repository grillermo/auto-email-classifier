# frozen_string_literal: true

module Rules
  class RuleEngine
    def initialize(gmail_client:, dry_run: false)
      @gmail_client = gmail_client
      @dry_run = dry_run
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

    def dry_run?
      @dry_run
    end

    def apply_for_rule(rule:, message:)
      rule_version = rule.version_digest
      existing = RuleApplication.find_by(
        gmail_message_id: message[:id],
        rule_id: rule.id,
        rule_version: rule_version
      )

      return matched_result(rule: rule, applied: false, reason: "already_applied", would_apply: false) if existing

      actions = ActionExecutor.new(
        rule: rule,
        message: message,
        gmail_client: gmail_client,
        dry_run: dry_run?
      ).execute!

      return matched_result(rule: rule, applied: false, actions: actions, dry_run: true, would_apply: true) if dry_run?

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

      matched_result(rule: rule, applied: true, actions: actions)
    rescue ActiveRecord::RecordNotUnique
      matched_result(rule: rule, applied: false, reason: "already_applied", would_apply: false)
    end

    def matched_result(rule:, applied:, actions: nil, reason: nil, dry_run: dry_run?, would_apply: nil)
      result = {
        matched: true,
        applied: applied,
        rule_id: rule.id,
        rule_name: rule.name
      }
      result[:actions] = actions unless actions.nil?
      result[:reason] = reason if reason
      return result unless dry_run

      result[:dry_run] = true
      result[:would_apply] = would_apply unless would_apply.nil?
      result
    end
  end
end
