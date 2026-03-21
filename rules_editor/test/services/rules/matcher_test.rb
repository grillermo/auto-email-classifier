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

  test "case_sensitive true requires exact case to match" do
    rule = Rule.new(
      name: "CS",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "Billing@", case_sensitive: true }],
        actions: [{ type: "mark_read" }]
      }
    )
    message_wrong_case = { from: "billing@example.com", subject: "", body: "" }
    message_right_case = { from: "Billing@example.com", subject: "", body: "" }

    assert_not Rules::Matcher.new(rule: rule, message: message_wrong_case).matches?
    assert     Rules::Matcher.new(rule: rule, message: message_right_case).matches?
  end

  test "body field is matched against message body" do
    rule = Rule.new(
      name: "Body",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "body", operator: "contains", value: "unsubscribe" }],
        actions: [{ type: "mark_read" }]
      }
    )
    assert     Rules::Matcher.new(rule: rule, message: { from: "", subject: "", body: "Click here to Unsubscribe" }).matches?
    assert_not Rules::Matcher.new(rule: rule, message: { from: "", subject: "", body: "Hello friend" }).matches?
  end

  test "any mode returns false when all conditions fail" do
    rule = Rule.new(
      name: "Any fail",
      priority: 1,
      definition: {
        match_mode: "any",
        conditions: [
          { field: "sender", operator: "contains", value: "alpha@" },
          { field: "subject", operator: "contains", value: "beta" }
        ],
        actions: [{ type: "mark_read" }]
      }
    )
    message = { from: "nope@example.com", subject: "nothing", body: "" }
    assert_not Rules::Matcher.new(rule: rule, message: message).matches?
  end
end
