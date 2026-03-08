# frozen_string_literal: true

require "test_helper"

class RulesEditTest < ActionDispatch::IntegrationTest
  setup do
    @rule = Rule.create!(
      name: "Important Sender",
      active: true,
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "boss@example.com" }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  test "edit renders the inertia edit page" do
    get edit_rule_path(@rule)

    assert_response :success
    assert_includes response.body, "&quot;component&quot;:&quot;Rules/Edit&quot;"
  end

  test "successful inertia update redirects with inertia location" do
    patch rule_path(@rule), params: valid_rule_params, headers: inertia_headers

    assert_response :conflict
    assert_equal rule_path(@rule), response.headers["X-Inertia-Location"]
    assert_equal "Updated rule", @rule.reload.name
  end

  test "invalid inertia update rerenders edit with errors" do
    invalid_params = valid_rule_params.deep_dup
    invalid_params[:rule][:name] = ""
    invalid_params[:rule][:conditions_attributes] = [
      { field: "sender", operator: "contains", value: "", case_sensitive: false }
    ]

    patch rule_path(@rule), params: invalid_params, headers: inertia_headers

    assert_response :unprocessable_entity

    payload = JSON.parse(response.body)
    assert_equal "Rules/Edit", payload["component"]
    assert_includes payload.dig("props", "errorMessages"), "Name can't be blank"
  end

  private

  def inertia_headers
    { "X-Inertia" => "true" }
  end

  def valid_rule_params
    {
      rule: {
        name: "Updated rule",
        active: true,
        priority: 2,
        match_mode: "all",
        conditions_attributes: [
          { field: "sender", operator: "contains", value: "updated@example.com", case_sensitive: false }
        ],
        actions_attributes: [
          { type: "mark_read", label: "" }
        ]
      },
      commit_action: "save"
    }
  end
end
