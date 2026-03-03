# frozen_string_literal: true

require "test_helper"

class RuleTest < ActiveSupport::TestCase
  test "is valid with required definition shape" do
    rule = Rule.new(
      name: "Valid",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "foo@example.com" }],
        actions: [{ type: "mark_read" }]
      }
    )

    assert rule.valid?
  end

  test "is invalid without actions" do
    rule = Rule.new(
      name: "Invalid",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "foo@example.com" }],
        actions: []
      }
    )

    assert_not rule.valid?
  end
end
