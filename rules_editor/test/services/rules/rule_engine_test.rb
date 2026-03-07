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
end
