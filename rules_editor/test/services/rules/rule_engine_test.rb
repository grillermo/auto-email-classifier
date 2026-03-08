# frozen_string_literal: true

require "test_helper"

class RulesRuleEngineTest < ActiveSupport::TestCase
  test "dry run returns planned actions without applying them or recording an application" do
    rule = Rule.create!(
      name: "Billing",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [
          { type: "add_label", label: "Finance" },
          { type: "mark_read" }
        ]
      }
    )

    message = {
      id: "gmail-123",
      from: "billing@example.com",
      subject: "Invoice",
      body: "Monthly invoice"
    }

    result = nil

    assert_no_difference "RuleApplication.count" do
      result = Rules::RuleEngine.new(gmail_client: Object.new, dry_run: true).process_message!(
        message: message,
        rules_scope: [rule]
      )
    end

    assert_equal true, result[:matched]
    assert_equal false, result[:applied]
    assert_equal true, result[:dry_run]
    assert_equal true, result[:would_apply]
    assert_equal rule.id, result[:rule_id]
    assert_equal rule.name, result[:rule_name]
    assert_equal(
      [
        { type: "add_label", label: "Finance" },
        { type: "mark_read" }
      ],
      result[:actions]
    )
  end

  test "dry run reports already applied messages without replaying actions" do
    rule = Rule.create!(
      name: "Billing",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    RuleApplication.create!(
      gmail_message_id: "gmail-123",
      rule: rule,
      rule_version: rule.version_digest,
      result: {},
      applied_at: Time.current
    )

    result = Rules::RuleEngine.new(gmail_client: Object.new, dry_run: true).process_message!(
      message: { id: "gmail-123", from: "billing@example.com", subject: "Invoice", body: "Monthly invoice" },
      rules_scope: [rule]
    )

    assert_equal true, result[:matched]
    assert_equal false, result[:applied]
    assert_equal true, result[:dry_run]
    assert_equal false, result[:would_apply]
    assert_equal "already_applied", result[:reason]
    assert_nil result[:actions]
  end

  test "records message metadata when applying a rule" do
    rule = Rule.create!(
      name: "Billing",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    gmail_client = Class.new do
      attr_reader :message_ids_marked_read

      def initialize
        @message_ids_marked_read = []
      end

      def mark_message_read(message_id)
        @message_ids_marked_read << message_id
      end
    end.new

    Rules::RuleEngine.new(gmail_client: gmail_client).process_message!(
      message: {
        id: "gmail-123",
        thread_id: "thread-123",
        date: "Fri, 07 Mar 2026 13:20:00 +0000",
        from: "billing@example.com",
        subject: "Invoice",
        body: "Monthly invoice"
      },
      rules_scope: [rule]
    )

    application = RuleApplication.find_by!(gmail_message_id: "gmail-123", rule_id: rule.id)

    assert_equal ["gmail-123"], gmail_client.message_ids_marked_read
    assert_equal "Invoice", application.result.dig("message", "subject")
    assert_equal "billing@example.com", application.result.dig("message", "from")
    assert_equal "Fri, 07 Mar 2026 13:20:00 +0000", application.result.dig("message", "date")
    assert_equal "thread-123", application.result.dig("message", "thread_id")
  end
end
