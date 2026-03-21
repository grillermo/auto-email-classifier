# frozen_string_literal: true

require "test_helper"

class RulesActionExecutorTest < ActiveSupport::TestCase
  class FakeGmailClient
    attr_reader :mark_read_ids, :trash_ids, :modifications, :ensured_labels

    def initialize
      @mark_read_ids = []
      @trash_ids = []
      @modifications = []
      @ensured_labels = []
    end

    def mark_message_read(id)
      @mark_read_ids << id
    end

    def trash_message(id)
      @trash_ids << id
    end

    def ensure_label_id(name)
      @ensured_labels << name
      "label-id-#{name}"
    end

    def modify_message(message_id:, add_label_ids: [], remove_label_ids: [])
      @modifications << { message_id: message_id, add: add_label_ids, remove: remove_label_ids }
    end
  end

  def rule_with_actions(actions)
    Rule.new(
      name: "Test",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "x@" }],
        actions: actions
      }
    )
  end

  MESSAGE = { id: "msg-1" }.freeze

  # --- mark_read ---

  test "mark_read in live mode calls mark_message_read on gmail client" do
    rule = rule_with_actions([{ type: "mark_read" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_equal ["msg-1"], client.mark_read_ids
    assert_equal [{ type: "mark_read" }], result
  end

  test "mark_read in dry_run mode does not call gmail client" do
    rule = rule_with_actions([{ type: "mark_read" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.mark_read_ids
    assert_equal [{ type: "mark_read" }], result
  end

  # --- trash ---

  test "trash in live mode calls trash_message on gmail client" do
    rule = rule_with_actions([{ type: "trash" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_equal ["msg-1"], client.trash_ids
    assert_equal [{ type: "trash" }], result
  end

  test "trash in dry_run mode does not call gmail client" do
    rule = rule_with_actions([{ type: "trash" }])
    client = FakeGmailClient.new

    Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.trash_ids
  end

  # --- add_label ---

  test "add_label in live mode ensures label and modifies message" do
    rule = rule_with_actions([{ type: "add_label", label: "Finance" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_includes client.ensured_labels, "Finance"
    assert_equal "msg-1", client.modifications.first[:message_id]
    assert_includes client.modifications.first[:add], "label-id-Finance"
    assert_equal [{ type: "add_label", label: "Finance" }], result
  end

  test "add_label in dry_run mode skips all gmail calls" do
    rule = rule_with_actions([{ type: "add_label", label: "Finance" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.ensured_labels
    assert_empty client.modifications
    assert_equal [{ type: "add_label", label: "Finance" }], result
  end

  # --- remove_label ---

  test "remove_label in live mode ensures label and removes it from message" do
    rule = rule_with_actions([{ type: "remove_label", label: "INBOX" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_includes client.ensured_labels, "INBOX"
    assert_includes client.modifications.first[:remove], "label-id-INBOX"
    assert_equal [{ type: "remove_label", label: "INBOX" }], result
  end

  test "remove_label in dry_run mode skips all gmail calls" do
    rule = rule_with_actions([{ type: "remove_label", label: "INBOX" }])
    client = FakeGmailClient.new

    Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.ensured_labels
    assert_empty client.modifications
  end

  # --- multiple actions ---

  test "multiple actions are all executed and returned" do
    rule = rule_with_actions([
      { type: "mark_read" },
      { type: "add_label", label: "Done" },
      { type: "trash" }
    ])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_equal 3, result.length
    assert_equal "mark_read", result[0][:type]
    assert_equal "add_label", result[1][:type]
    assert_equal "trash", result[2][:type]
    assert_equal ["msg-1"], client.mark_read_ids
    assert_equal ["msg-1"], client.trash_ids
    assert_includes client.ensured_labels, "Done"
  end
end
