# frozen_string_literal: true

require "test_helper"

class RuleTest < ActiveSupport::TestCase
  test "is valid with required definition shape" do
    rule = Rule.new(
      name: "Valid",
      priority: 1,
      definition: valid_definition
    )

    assert rule.valid?
  end

  test "is invalid without actions" do
    rule = Rule.new(
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

  test "is invalid when definition is duplicated" do
    Rule.create!(
      name: "Original",
      priority: 1,
      definition: valid_definition
    )

    duplicate = Rule.new(
      name: "Duplicate",
      priority: 2,
      definition: valid_definition
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:definition], "has already been taken"
  end

  test "database enforces unique definition" do
    now = Time.current
    definition = valid_definition

    Rule.insert_all!([
      {
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

  private

  def valid_definition
    {
      match_mode: "all",
      conditions: [{ field: "sender", operator: "contains", value: "foo@example.com" }],
      actions: [{ type: "mark_read" }]
    }
  end
end
