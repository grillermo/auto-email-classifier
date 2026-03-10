# frozen_string_literal: true

require "test_helper"

class RulesMatcherTest < ActiveSupport::TestCase
  test "matches all conditions" do
    rule = Rule.new(
      name: "All",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [
          { field: "sender", operator: "contains", value: "billing@" },
        ],
        actions: [{ type: "mark_read" }]
      }
    )

    message = { from: "Billing@Company.com", subject: "invoice", body: "hello" }

    assert Rules::Matcher.new(rule: rule, message: message).matches?
  end

  test "does not match when all mode has one failing condition" do
    rule = Rule.new(
      name: "All",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [
          { field: "sender", operator: "contains", value: "billing@" },
          { field: "subject", operator: "contains", value: "receipt" }
        ],
        actions: [{ type: "mark_read" }]
      }
    )

    message = { from: "billing@company.com", subject: "invoice", body: "hello" }

    assert_not Rules::Matcher.new(rule: rule, message: message).matches?
  end

  test "matches any mode when one condition matches" do
    rule = Rule.new(
      name: "Any",
      priority: 1,
      definition: {
        match_mode: "any",
        conditions: [
          { field: "sender", operator: "contains", value: "alerts@example.com" },
          { field: "subject", operator: "contains", value: "payment" }
        ],
        actions: [{ type: "mark_read" }]
      }
    )

    message = { from: "noreply@example.com", subject: "Payment received", body: "hello" }

    assert Rules::Matcher.new(rule: rule, message: message).matches?
  end
end
