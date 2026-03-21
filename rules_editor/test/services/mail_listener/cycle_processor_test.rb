# frozen_string_literal: true

require "test_helper"

class MailListenerCycleProcessorTest < ActiveSupport::TestCase
  class FakeGmailClient
    attr_reader :fetched_ids, :mark_read_ids

    def initialize(messages: {}, message_ids: [])
      @messages = messages
      @message_ids_list = message_ids
      @fetched_ids = []
      @mark_read_ids = []
    end

    def list_message_ids(query:, max_results:)
      # Return empty for classify queries so AutoRulesCreator does nothing and
      # never calls apply_rule -> OneOffApplier.new(rule:) -> Gmail::Client.new.
      return [] if query.start_with?("label:")
      @message_ids_list.take(max_results)
    end

    def fetch_normalized_message(id)
      @fetched_ids << id
      @messages.fetch(id, { id: id, from: "", subject: "", body: "" })
    end

    def mark_message_read(id)
      @mark_read_ids << id
    end

    def profile
      Struct.new(:email_address).new("owner@example.com")
    end
  end

  def create_rule(value: "billing@")
    Rule.create!(
      name: "Billing",
      priority: 1,
      active: true,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: value }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  test "process! fetches messages and applies matching rules" do
    rule = create_rule
    client = FakeGmailClient.new(
      message_ids: ["msg-1"],
      messages: { "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "inv", body: "" } }
    )
    # FakeGmailClient returns [] for the classify query (label:*) so AutoRulesCreator
    # does nothing. The inbox query returns ["msg-1"] which gets processed by RuleEngine.

    capture_io do
      MailListener::CycleProcessor.new(gmail_client: client).process!
    end

    assert RuleApplication.exists?(gmail_message_id: "msg-1", rule_id: rule.id)
  end

  test "dry_run mode does not create rule applications" do
    create_rule
    client = FakeGmailClient.new(
      message_ids: ["msg-1"],
      messages: { "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "inv", body: "" } }
    )

    assert_no_difference "RuleApplication.count" do
      capture_io do
        MailListener::CycleProcessor.new(gmail_client: client, dry_run: true).process!
      end
    end
  end

  test "process! catches and logs StandardError without raising" do
    exploding_client = Class.new do
      def list_message_ids(query:, max_results:) = raise StandardError, "connection refused"
      def profile = Struct.new(:email_address).new("x@example.com")
    end.new

    # Should not raise
    output = capture_io do
      assert_nothing_raised do
        MailListener::CycleProcessor.new(gmail_client: exploding_client).process!
      end
    end.first

    assert_includes output, "cycle failed"
  end

  test "process! sends ntfy notification on authorization error when channel is configured" do
    auth_error_client = Class.new do
      def list_message_ids(query:, max_results:)
        raise RuntimeError, "Authorization failed — please re-authenticate"
      end
      def profile = Struct.new(:email_address).new("x@example.com")
    end.new

    ntfy_called = false
    ENV["NTFY_CHANNEL"] = "test-channel"

    HTTP.stub(:post, ->(_url, **_opts) { ntfy_called = true }) do
      capture_io do
        MailListener::CycleProcessor.new(gmail_client: auth_error_client).process!
      end
    end

    assert ntfy_called, "Expected HTTP.post to be called for ntfy notification"
  ensure
    ENV.delete("NTFY_CHANNEL")
  end

  test "skips ntfy notification when NTFY_CHANNEL is not set" do
    auth_error_client = Class.new do
      def list_message_ids(query:, max_results:)
        raise RuntimeError, "Authorization failed"
      end
      def profile = Struct.new(:email_address).new("x@example.com")
    end.new

    ENV.delete("NTFY_CHANNEL")
    ntfy_called = false

    HTTP.stub(:post, ->(_url, **_opts) { ntfy_called = true }) do
      capture_io do
        MailListener::CycleProcessor.new(gmail_client: auth_error_client).process!
      end
    end

    assert_not ntfy_called
  end
end
