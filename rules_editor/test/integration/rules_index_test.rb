# frozen_string_literal: true

require "test_helper"

class RulesIndexTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
    sign_in @user
  end

  test "index returns serialized active and inactive rules" do
    @user.rules.create!(
      name: "Active Rule",
      active: true,
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "a@" }],
        actions: [{ type: "mark_read" }, { type: "trash" }]
      }
    )

    @user.rules.create!(
      name: "Inactive Rule",
      active: false,
      priority: 2,
      definition: {
        match_mode: "all",
        conditions: [{ field: "subject", operator: "contains", value: "b@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    get rules_path, headers: { "X-Inertia" => "true" }

    assert_response :success
    payload = JSON.parse(response.body)

    active_rules = payload.dig("props", "activeRules")
    inactive_rules = payload.dig("props", "inactiveRules")

    assert_equal 1, active_rules.length
    assert_equal "Active Rule", active_rules.first["name"]
    assert_equal 1, active_rules.first["conditionsCount"]
    assert_equal 2, active_rules.first["actionsCount"]

    assert_equal 1, inactive_rules.length
    assert_equal "Inactive Rule", inactive_rules.first["name"]
  end
end
