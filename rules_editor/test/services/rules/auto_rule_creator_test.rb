# frozen_string_literal: true

require "test_helper"

class RulesAutoRulesCreatorTest < ActiveSupport::TestCase
  FakeProfile = Struct.new(:email_address)

  class FakeGmailClient
    attr_reader :mark_read_ids, :sent_messages, :last_query

    def initialize
      @mark_read_ids = []
      @sent_messages = []
      @last_query = nil
    end

    def list_message_ids(query:, max_results:)
      @last_query = query
      ["msg-1"]
    end

    def profile
      FakeProfile.new("owner@example.com")
    end

    def fetch_normalized_message(message_id)
      { id: message_id, from: "Billing Team <billing@example.com>", subject: "Invoice" }
    end

    def mark_message_read(message_id)
      @mark_read_ids << message_id
    end

    def send_plain_text(**payload)
      @sent_messages << payload
      Struct.new(:id).new("notification-1")
    end
  end

  test "dry run uses classify label query and logs rule creation without mutating gmail" do
    gmail_client = FakeGmailClient.new
    processor = Rules::AutoRulesCreator.new(gmail_client: gmail_client, dry_run: true)

    previous_classify_query = ENV.delete("AUTO_RULE_CLASSIFY_QUERY")
    previous_forward_query = ENV.delete("AUTO_CLASSIFY_QUERY")

    result = nil
    output = begin
      capture_io do
        assert_no_difference "Rule.count" do
          assert_no_difference "AutoRuleEvent.count" do
            result = processor.process!
          end
        end
      end.first
    ensure
      ENV["AUTO_RULE_CLASSIFY_QUERY"] = previous_classify_query
      ENV["AUTO_CLASSIFY_QUERY"] = previous_forward_query
    end

    assert_equal 1, result[:inspected]
    assert_equal 1, result[:created]
    assert_equal Rules::AutoRulesCreator::DEFAULT_CLASSIFY_QUERY, gmail_client.last_query
    assert_empty gmail_client.mark_read_ids
    assert_empty gmail_client.sent_messages
    assert_includes output, "would create inactive rule"
    assert_includes output, "would send confirmation email"
    assert_includes output, "would mark classify email as read"
  end
end
