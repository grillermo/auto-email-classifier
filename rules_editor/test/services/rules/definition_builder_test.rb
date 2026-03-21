# frozen_string_literal: true

require "test_helper"

class RulesDefinitionBuilderTest < ActiveSupport::TestCase
  test "builds definition with match_mode, conditions and actions" do
    params = {
      match_mode: "any",
      conditions_attributes: [
        { field: "subject", operator: "contains", value: "Invoice", case_sensitive: "false" }
      ],
      actions_attributes: [
        { type: "mark_read", label: "" }
      ]
    }

    result = Rules::DefinitionBuilder.new(params).build

    assert_equal "any", result[:match_mode]
    assert_equal 1, result[:conditions].length
    assert_equal "subject", result[:conditions].first[:field]
    assert_equal "Invoice", result[:conditions].first[:value]
    assert_equal false, result[:conditions].first[:case_sensitive]
    assert_equal 1, result[:actions].length
    assert_equal "mark_read", result[:actions].first[:type]
  end

  test "match_mode defaults to 'all' for invalid value" do
    params = { match_mode: "whatever", conditions_attributes: [], actions_attributes: [] }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal "all", result[:match_mode]
  end

  test "strips whitespace from condition values" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "  billing@  ", case_sensitive: false }],
      actions_attributes: [{ type: "mark_read" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal "billing@", result[:conditions].first[:value]
  end

  test "skips conditions with blank value" do
    params = {
      match_mode: "all",
      conditions_attributes: [
        { field: "sender", operator: "contains", value: "", case_sensitive: false },
        { field: "subject", operator: "contains", value: "Invoice", case_sensitive: false }
      ],
      actions_attributes: [{ type: "mark_read" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal 1, result[:conditions].length
    assert_equal "Invoice", result[:conditions].first[:value]
  end

  test "case_sensitive as array uses last element (checkbox quirk)" do
    params = {
      match_mode: "all",
      conditions_attributes: [
        { field: "sender", operator: "contains", value: "x@", case_sensitive: ["0", "1"] }
      ],
      actions_attributes: [{ type: "mark_read" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal true, result[:conditions].first[:case_sensitive]
  end

  test "skips actions with empty type" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "x@", case_sensitive: false }],
      actions_attributes: [
        { type: "", label: "" },
        { type: "mark_read", label: "" }
      ]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal 1, result[:actions].length
    assert_equal "mark_read", result[:actions].first[:type]
  end

  test "label included for add_label action" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "x@", case_sensitive: false }],
      actions_attributes: [{ type: "add_label", label: "Finance" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    action = result[:actions].first
    assert_equal "add_label", action[:type]
    assert_equal "Finance", action[:label]
  end

  test "label not included for mark_read action" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "x@", case_sensitive: false }],
      actions_attributes: [{ type: "mark_read", label: "ignored" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_not result[:actions].first.key?(:label)
  end

  test "handles conditions_attributes as a Hash (ActionController::Parameters style)" do
    # Simulates how Rails submits nested params: {"0" => {...}, "1" => {...}}
    params = {
      match_mode: "all",
      conditions_attributes: { "0" => { field: "sender", operator: "contains", value: "x@", case_sensitive: false } },
      actions_attributes: { "0" => { type: "mark_read" } }
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal 1, result[:conditions].length
    assert_equal 1, result[:actions].length
  end
end
