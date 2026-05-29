# frozen_string_literal: true

require "test_helper"

class RulesEditTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
    sign_in @user

    @rule = @user.rules.create!(
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

  test "edit includes executable action scripts in props" do
    stub_method(Rules::ActionScripts, :available_scripts, ["sync.sh", "mail/archive.rb"]) do
      get edit_rule_path(@rule), headers: inertia_headers

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal ["sync.sh", "mail/archive.rb"], payload.dig("props", "actionScripts")
    end
  end

  test "new renders a blank inertia edit page configured for create" do
    get new_rule_path, headers: inertia_headers

    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal "Rules/Edit", payload["component"]
    assert_equal "", payload.dig("props", "rule", "name")
    assert_equal true, payload.dig("props", "rule", "active")
    assert_equal 2, payload.dig("props", "rule", "priority")
    assert_equal rules_path, payload.dig("props", "updateUrl")
    assert_equal "post", payload.dig("props", "submitMethod")
    assert_nil payload.dig("props", "deleteUrl")
  end

  test "successful inertia create redirects to the new rule edit page" do
    post rules_path, params: valid_rule_params, headers: inertia_headers

    created_rule = @user.rules.order(created_at: :desc).first

    assert_response :conflict
    assert_equal edit_rule_path(created_rule), response.headers["X-Inertia-Location"]
    assert_equal "Updated rule", created_rule.name
    assert_equal 2, created_rule.priority
    assert_equal "updated@example.com", created_rule.conditions.first[:value]
  end

  test "invalid inertia create rerenders edit with errors" do
    invalid_params = valid_rule_params.deep_dup
    invalid_params[:rule][:name] = ""
    invalid_params[:rule][:conditions_attributes] = [
      { field: "sender", operator: "contains", value: "", case_sensitive: false }
    ]

    post rules_path, params: invalid_params, headers: inertia_headers

    assert_response :unprocessable_entity

    payload = JSON.parse(response.body)
    assert_equal "Rules/Edit", payload["component"]
    assert_equal "post", payload.dig("props", "submitMethod")
    assert_includes payload.dig("props", "errorMessages"), "Name can't be blank"
  end

  test "successful inertia update redirects with inertia location" do
    patch rule_path(@rule), params: valid_rule_params, headers: inertia_headers

    assert_response :conflict
    assert_equal edit_rule_path(@rule), response.headers["X-Inertia-Location"]
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
    assert_equal({}, payload.dig("props", "errors"))
    assert_includes payload.dig("props", "errorMessages"), "Name can't be blank"
  end

  test "save_and_apply applies rule to inbox and shows matched/applied in flash" do
    # Stub OneOffApplier so no real Gmail call is made
    fake_applier = Object.new.tap { |obj|
      obj.define_singleton_method(:apply!) { |**_| { matched_count: 3, applied_count: 2 } }
    }
    fake_gmail_client = Object.new
    stub_method(Gmail::Client, :for_authentication, fake_gmail_client) do
      stub_method(Rules::OneOffApplier, :new, ->(**_) { fake_applier }) do
        patch rule_path(@rule),
          params: valid_rule_params.merge(commit_action: "save_and_apply"),
          headers: inertia_headers

        assert_response :conflict
        assert_equal edit_rule_path(@rule), response.headers["X-Inertia-Location"]
        assert_match "matched: 3", flash[:notice]
        assert_match "applied: 2", flash[:notice]
      end
    end
  end

  test "save_and_apply sets alert flash when OneOffApplier raises" do
    fake_applier = Object.new.tap { |obj|
      obj.define_singleton_method(:apply!) { |**_| raise StandardError, "Gmail error" }
    }
    fake_gmail_client = Object.new
    stub_method(Gmail::Client, :for_authentication, fake_gmail_client) do
      stub_method(Rules::OneOffApplier, :new, ->(**_) { fake_applier }) do
        patch rule_path(@rule),
          params: valid_rule_params.merge(commit_action: "save_and_apply"),
          headers: inertia_headers

        assert_response :conflict
        assert_match "Gmail error", flash[:alert]
      end
    end
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
          { type: "mark_read", label: "", script: "" }
        ]
      },
      commit_action: "save"
    }
  end
end
