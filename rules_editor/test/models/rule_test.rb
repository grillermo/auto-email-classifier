# frozen_string_literal: true

require "test_helper"

class RuleTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "is valid with required definition shape" do
    rule = @user.rules.new(
      name: "Valid",
      priority: 1,
      definition: valid_definition
    )

    assert rule.valid?
  end

  test "is invalid without actions" do
    rule = @user.rules.new(
      name: "Invalid",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "alerts@example.com" }],
        actions: []
      }
    )

    assert_not rule.valid?
  end

  test "is invalid when definition is duplicated for same user" do
    @user.rules.create!(
      name: "Original",
      priority: 1,
      definition: valid_definition
    )

    duplicate = @user.rules.new(
      name: "Duplicate",
      priority: 2,
      definition: valid_definition
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:definition], "has already been taken"
  end

  test "same definition is valid for different users" do
    other_user = User.create!(email: "other@example.com")
    @user.rules.create!(name: "Original", priority: 1, definition: valid_definition)

    other_rule = other_user.rules.new(name: "Other", priority: 1, definition: valid_definition)
    assert other_rule.valid?
  end

  test "database enforces unique definition per user" do
    now = Time.current
    definition = valid_definition

    Rule.insert_all!([
      {
        user_id: @user.id,
        name: "Original",
        priority: 1,
        active: true,
        definition: definition,
        metadata: {},
        created_at: now,
        updated_at: now
      }
    ])

    assert_raises ActiveRecord::RecordNotUnique do
      Rule.insert_all!([
        {
          user_id: @user.id,
          name: "Duplicate",
          priority: 2,
          active: true,
          definition: definition,
          metadata: {},
          created_at: now,
          updated_at: now
        }
      ])
    end
  end

  test "next_priority returns one more than the highest existing priority" do
    @user.rules.create!(name: "A", priority: 5, definition: valid_definition)
    @user.rules.create!(name: "B", priority: 10, definition: valid_definition(value: "b@"))
    assert_equal 11, Rule.next_priority
  end

  test "next_priority returns 1 when no rules exist" do
    assert_equal 1, Rule.next_priority
  end

  test "version_digest changes when updated_at changes" do
    rule = @user.rules.create!(name: "R", priority: 1, definition: valid_definition)
    digest_before = rule.version_digest
    rule.update!(name: "R updated")
    assert_not_equal digest_before, rule.version_digest
  end

  test "conditions returns array with indifferent access" do
    rule = Rule.new(definition: valid_definition)
    cond = rule.conditions.first
    assert_equal "sender", cond[:field]
    assert_equal "sender", cond["field"]
  end

  test "actions returns array with indifferent access" do
    rule = Rule.new(definition: valid_definition)
    action = rule.actions.first
    assert_equal "mark_read", action[:type]
    assert_equal "mark_read", action["type"]
  end

  test "match_mode returns all by default when missing from definition" do
    rule = Rule.new(definition: { "conditions" => [], "actions" => [] })
    assert_equal "all", rule.match_mode
  end

  test "active scope excludes inactive rules" do
    @user.rules.create!(name: "Active", priority: 1, active: true, definition: valid_definition)
    @user.rules.create!(name: "Inactive", priority: 2, active: false, definition: valid_definition(value: "b@"))
    assert_equal ["Active"], @user.rules.active.map(&:name)
  end

  test "ordered scope sorts by priority ascending" do
    @user.rules.create!(name: "Second", priority: 2, definition: valid_definition)
    @user.rules.create!(name: "First", priority: 1, definition: valid_definition(value: "b@"))
    assert_equal ["First", "Second"], @user.rules.ordered.map(&:name)
  end

  test "ensure_definition_hash coerces nil definition to empty hash" do
    rule = Rule.new(name: "R", priority: 1)
    rule.valid?  # triggers before_validation
    assert_equal({}, rule.definition)
  end

  test "invalid match_mode fails validation" do
    rule = @user.rules.new(name: "R", priority: 1, definition: valid_definition.merge("match_mode" => "invalid"))
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "match_mode must be 'all' or 'any'"
  end

  test "condition with invalid field fails validation" do
    defn = valid_definition
    defn["conditions"] = [{ field: "invalid_field", operator: "contains", value: "x" }]
    rule = @user.rules.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "condition field is invalid"
  end

  test "condition with invalid operator fails validation" do
    defn = valid_definition
    defn["conditions"] = [{ field: "sender", operator: "equals", value: "x" }]
    rule = @user.rules.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "condition operator is invalid"
  end

  test "condition with blank value fails validation" do
    defn = valid_definition
    defn["conditions"] = [{ field: "sender", operator: "contains", value: "   " }]
    rule = @user.rules.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "condition value cannot be blank"
  end

  test "action with invalid type fails validation" do
    defn = valid_definition
    defn["actions"] = [{ type: "teleport" }]
    rule = @user.rules.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "action type is invalid"
  end

  test "add_label action without label fails validation" do
    defn = valid_definition
    defn["actions"] = [{ type: "add_label", label: "" }]
    rule = @user.rules.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "label action requires a label"
  end

  test "remove_label action without label fails validation" do
    defn = valid_definition
    defn["actions"] = [{ type: "remove_label", label: "  " }]
    rule = @user.rules.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "label action requires a label"
  end

  private

  def valid_definition(value: "billing@")
    {
      "match_mode" => "all",
      "conditions" => [{ "field" => "sender", "operator" => "contains", "value" => value }],
      "actions" => [{ "type" => "mark_read" }]
    }
  end
end
