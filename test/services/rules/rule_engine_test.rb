# frozen_string_literal: true

require "test_helper"

class RulesRuleEngineTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  def create_rule(name: "Billing", value: "billing@", actions: [{ type: "mark_read" }])
    @user.rules.create!(
      name: name,
      priority: @user.rules.count + 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: value }],
        actions: actions
      }
    )
  end

  test "dry run returns planned actions without applying them or recording an application" do
    rule = create_rule(actions: [{ type: "add_label", label: "Finance" }, { type: "mark_read" }])

    message = {
      id: "gmail-123",
      from: "billing@example.com",
      subject: "Invoice",
      body: "Monthly invoice"
    }

    result = nil

    assert_no_difference "RuleApplication.count" do
      result = Rules::RuleEngine.new(gmail_client: Object.new, dry_run: true).process_message!(
        message: message,
        rules_scope: [rule]
      )
    end

    assert_equal true, result[:matched]
    assert_equal false, result[:applied]
    assert_equal true, result[:dry_run]
    assert_equal true, result[:would_apply]
    assert_equal rule.id, result[:rule_id]
    assert_equal rule.name, result[:rule_name]
    assert_equal(
      [
        { type: "add_label", label: "Finance" },
        { type: "mark_read" }
      ],
      result[:actions]
    )
  end

  test "dry run reports already applied messages without replaying actions" do
    rule = create_rule

    RuleApplication.create!(
      gmail_message_id: "gmail-123",
      rule: rule,
      user: @user,
      rule_version: rule.version_digest,
      result: {},
      applied_at: Time.current
    )

    result = Rules::RuleEngine.new(gmail_client: Object.new, dry_run: true).process_message!(
      message: { id: "gmail-123", from: "billing@example.com", subject: "Invoice", body: "Monthly invoice" },
      rules_scope: [rule]
    )

    assert_equal true, result[:matched]
    assert_equal false, result[:applied]
    assert_equal true, result[:dry_run]
    assert_equal false, result[:would_apply]
    assert_equal "already_applied", result[:reason]
    assert_nil result[:actions]
  end

  test "records message metadata when applying a rule" do
    rule = create_rule

    gmail_client = Class.new do
      attr_reader :message_ids_marked_read

      def initialize
        @message_ids_marked_read = []
      end

      def mark_message_read(message_id)
        @message_ids_marked_read << message_id
      end
    end.new

    Rules::RuleEngine.new(gmail_client: gmail_client).process_message!(
      message: {
        id: "gmail-123",
        thread_id: "thread-123",
        date: "Fri, 07 Mar 2026 13:20:00 +0000",
        from: "billing@example.com",
        subject: "Invoice",
        body: "Monthly invoice"
      },
      rules_scope: [rule]
    )

    application = RuleApplication.find_by!(gmail_message_id: "gmail-123", rule_id: rule.id)

    assert_equal ["gmail-123"], gmail_client.message_ids_marked_read
    assert_equal "Invoice", application.result.dig("message", "subject")
    assert_equal "billing@example.com", application.result.dig("message", "from")
    assert_equal "Fri, 07 Mar 2026 13:20:00 +0000", application.result.dig("message", "date")
    assert_equal "thread-123", application.result.dig("message", "thread_id")
  end

  test "returns matched: false when no rule matches the message" do
    rule = create_rule(value: "vip@")

    result = Rules::RuleEngine.new(gmail_client: Object.new).process_message!(
      message: { id: "msg-1", from: "nobody@example.com", subject: "hi", body: "" },
      rules_scope: [rule]
    )

    assert_equal false, result[:matched]
  end

  test "stops at the first matching rule and does not evaluate later rules" do
    rule_one = create_rule(name: "First", value: "billing@", actions: [{ type: "mark_read" }])
    rule_two = create_rule(name: "Second", value: "billing@", actions: [{ type: "trash" }])

    gmail_client = Class.new do
      attr_reader :mark_read_ids, :trash_ids
      def initialize
        @mark_read_ids = []
        @trash_ids = []
      end
      def mark_message_read(id) = @mark_read_ids << id
      def trash_message(id) = @trash_ids << id
    end.new

    Rules::RuleEngine.new(gmail_client: gmail_client).process_message!(
      message: { id: "msg-1", from: "billing@example.com", subject: "inv", body: "" },
      rules_scope: [rule_one, rule_two]
    )

    assert_equal ["msg-1"], gmail_client.mark_read_ids
    assert_empty gmail_client.trash_ids
  end

  test "live run with add_label action calls Gmail client and records application" do
    rule = create_rule(name: "Labels", actions: [{ type: "add_label", label: "Finance" }])

    gmail_client = Class.new do
      attr_reader :ensured_labels, :modifications
      def initialize
        @ensured_labels = []
        @modifications = []
      end
      def ensure_label_id(name) = @ensured_labels << name and "label-id-#{name}"
      def modify_message(message_id:, add_label_ids: [], remove_label_ids: [])
        @modifications << { message_id: message_id, add: add_label_ids, remove: remove_label_ids }
      end
    end.new

    assert_difference "RuleApplication.count", 1 do
      Rules::RuleEngine.new(gmail_client: gmail_client).process_message!(
        message: { id: "msg-2", from: "billing@example.com", subject: "Invoice", body: "" },
        rules_scope: [rule]
      )
    end

    assert_includes gmail_client.ensured_labels, "Finance"
    assert_equal "msg-2", gmail_client.modifications.first[:message_id]
  end
end
