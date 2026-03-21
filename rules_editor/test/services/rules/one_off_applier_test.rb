# frozen_string_literal: true

require "test_helper"

class RulesOneOffApplierTest < ActiveSupport::TestCase
  def billing_rule
    Rule.create!(
      name: "Billing",
      priority: 1,
      active: true,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  class FakeGmailClient
    attr_reader :mark_read_ids

    def initialize(messages)
      @messages = messages
      @mark_read_ids = []
    end

    def fetch_normalized_message(id)
      @messages.fetch(id)
    end

    def list_message_ids(query:, max_results:)
      @messages.keys.take(max_results)
    end

    def mark_message_read(id)
      @mark_read_ids << id
    end
  end

  test "apply! with message_id applies rule to that single message" do
    rule = billing_rule
    client = FakeGmailClient.new({
      "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "Invoice", body: "" }
    })

    result = Rules::OneOffApplier.new(rule: rule, gmail_client: client).apply!(message_id: "msg-1")

    assert_equal 1, result[:matched_count]
    assert_equal 1, result[:applied_count]
    assert_includes client.mark_read_ids, "msg-1"
  end

  test "apply! with message_id returns applied_count 0 when already applied" do
    rule = billing_rule
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-1",
      rule_version: rule.version_digest,
      result: {},
      applied_at: Time.current
    )
    client = FakeGmailClient.new({
      "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "Invoice", body: "" }
    })

    result = Rules::OneOffApplier.new(rule: rule, gmail_client: client).apply!(message_id: "msg-1")

    assert_equal 1, result[:matched_count]
    assert_equal 0, result[:applied_count]
  end

  test "apply! with query processes all matching messages" do
    rule = billing_rule
    client = FakeGmailClient.new({
      "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "A", body: "" },
      "msg-2" => { id: "msg-2", from: "noreply@example.com", subject: "B", body: "" },
      "msg-3" => { id: "msg-3", from: "billing@example.com", subject: "C", body: "" }
    })

    result = Rules::OneOffApplier.new(rule: rule, gmail_client: client).apply!(query: "in:inbox")

    assert_equal 2, result[:matched_count]
    assert_equal 2, result[:applied_count]
  end

  test "apply! with neither message_id nor query raises ArgumentError" do
    rule = billing_rule
    applier = Rules::OneOffApplier.new(rule: rule, gmail_client: Object.new)
    assert_raises(ArgumentError) { applier.apply! }
  end
end
