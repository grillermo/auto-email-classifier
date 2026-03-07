# frozen_string_literal: true

require "test_helper"

class RulesForwardedRuleProcessorTest < ActiveSupport::TestCase
  FakeProfile = Struct.new(:email_address)

  class FakeGmailClient
    attr_reader :mark_read_ids, :sent_messages

    def initialize
      @mark_read_ids = []
      @sent_messages = []
    end

    def list_message_ids(query:, max_results:)
      ["msg-1"]
    end

    def profile
      FakeProfile.new("owner@example.com")
    end

    def fetch_normalized_message(message_id)
      { id: message_id, body: "forwarded message body" }
    end

    def mark_message_read(message_id)
      @mark_read_ids << message_id
    end

    def send_plain_text(**payload)
      @sent_messages << payload
      Struct.new(:id).new("notification-1")
    end
  end

  class FakeParser
    def parse(_body)
      { sender: "billing@example.com", subject: "Invoice" }
    end
  end

  test "dry run logs forwarded rule creation without persisting or mutating gmail" do
    gmail_client = FakeGmailClient.new
    processor = Rules::ForwardedRuleProcessor.new(
      gmail_client: gmail_client,
      parser: FakeParser.new,
      dry_run: true
    )

    result = nil
    output = capture_io do
      assert_no_difference "Rule.count" do
        assert_no_difference "AutoRuleEvent.count" do
          result = processor.process!
        end
      end
    end.first

    assert_equal 1, result[:inspected]
    assert_equal 1, result[:created]
    assert_empty gmail_client.mark_read_ids
    assert_empty gmail_client.sent_messages
    assert_includes output, "would create inactive rule"
    assert_includes output, "would send confirmation email"
    assert_includes output, "would mark forwarded email as read"
  end
end
