# frozen_string_literal: true

require "test_helper"

class RulesReorderTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
    sign_in @user

    @rule_one = @user.rules.create!(
      name: "One",
      active: true,
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "one@example.com" }],
        actions: [{ type: "mark_read" }]
      }
    )

    @rule_two = @user.rules.create!(
      name: "Two",
      active: true,
      priority: 2,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "two@example.com" }],
        actions: [{ type: "mark_read" }]
      }
    )

    @user.rules.create!(
      name: "Inactive",
      active: false,
      priority: 3,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "inactive@example.com" }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  test "reorders active rules" do
    patch reorder_rules_path, params: { ordered_ids: [@rule_two.id, @rule_one.id] }, as: :json

    assert_response :success
    assert_equal 1, @rule_two.reload.priority
    assert_equal 2, @rule_one.reload.priority
  end

  test "returns unprocessable entity for invalid payload" do
    patch reorder_rules_path, params: { ordered_ids: [@rule_one.id] }, as: :json

    assert_response :unprocessable_entity
  end
end
