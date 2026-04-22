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

  setup do
    @user = User.create!(email: "test@example.com")
    @gmail_auth = GmailAuthentication.new(user: @user, email: "gmail@example.com")
    @gmail_client = FakeGmailClient.new
  end

  test "dry run uses classify label query and logs rule creation without mutating gmail" do
    previous_classify_label = ENV.delete("AUTO_CLASSIFY_LABEL")

    result = nil
    output = nil
    begin
      stub_method(Gmail::Client, :for_authentication, @gmail_client) do
        output = capture_io do
          assert_no_difference "Rule.count" do
            assert_no_difference "AutoRuleEvent.count" do
              result = Rules::AutoRulesCreator.new(gmail_authentication: @gmail_auth, dry_run: true).process!
            end
          end
        end.first
      end
    ensure
      ENV["AUTO_CLASSIFY_LABEL"] = previous_classify_label
    end

    assert_equal 1, result[:inspected]
    assert_equal 1, result[:created]
    assert_equal "label:#{Rules::AutoRulesCreator::DEFAULT_LABEL_TO_CLASSIFY}", @gmail_client.last_query
    assert_empty @gmail_client.mark_read_ids
    assert_empty @gmail_client.sent_messages
    assert_includes output, "would create inactive rule"
    assert_includes output, "would send ntfy notification to channel="
    assert_includes output, "would mark classify email as read"
  end

  # FakeOneOffApplier prevents AutoRulesCreator#apply_rule from calling
  # OneOffApplier.new(rule:) without a gmail_client, which would default to Gmail::Client.new
  FakeOneOffApplierResult = Struct.new(:matched_count, :applied_count)
  class FakeOneOffApplier
    def initialize(rule:, gmail_client: nil); end
    def apply!(**) = { matched_count: 1, applied_count: 1 }
  end

  test "live run creates a Rule and AutoRuleEvent for each classify message" do
    ENV.delete("NTFY_CHANNEL")  # ensure no ntfy HTTP call

    result = nil
    # Stub OneOffApplier so apply_rule never calls Gmail::Client.new
    stub_method(Gmail::Client, :for_authentication, @gmail_client) do
      stub_method(Rules::OneOffApplier, :new, ->(rule:, **) { FakeOneOffApplier.new(rule: rule) }) do
        capture_io do
          assert_difference "Rule.count", 1 do
            assert_difference "AutoRuleEvent.count", 1 do
              result = Rules::AutoRulesCreator.new(gmail_authentication: @gmail_auth, dry_run: false).process!
            end
          end
        end
      end
    ensure
      Rules::OneOffApplier.define_singleton_method(:new, &original_new)
    end

    assert_equal 1, result[:created]
    rule = Rule.last
    assert_equal false, rule.active  # auto rules are inactive by default
    assert_match "Auto:", rule.name
    assert_equal @user, rule.user

    event = AutoRuleEvent.last
    assert_equal "msg-1", event.source_gmail_message_id
    assert_equal rule, event.created_rule
    assert_equal @user, event.user
  end

  test "live run skips message if AutoRuleEvent already exists for it" do
    existing_rule = @user.rules.create!(
      name: "Existing",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "x@" }],
        actions: [{ type: "mark_read" }]
      }
    )
    @user.auto_rule_events.create!(
      source_gmail_message_id: "msg-1",
      created_rule: existing_rule
    )

    result = nil
    stub_method(Gmail::Client, :for_authentication, @gmail_client) do
      capture_io do
        assert_no_difference "Rule.count" do
          result = Rules::AutoRulesCreator.new(gmail_authentication: @gmail_auth, dry_run: false).process!
        end
      end
    end

    assert_equal 0, result[:created]
  end

  test "returns zero counts when gmail returns no classify messages" do
    empty_client = Class.new do
      def list_message_ids(query:, max_results:) = []
      def profile = Struct.new(:email_address).new("owner@example.com")
    end.new

    result = nil
    stub_method(Gmail::Client, :for_authentication, empty_client) do
      capture_io do
        result = Rules::AutoRulesCreator.new(gmail_authentication: @gmail_auth, dry_run: false).process!
      end
    end

    assert_equal 0, result[:inspected]
    assert_equal 0, result[:created]
  end
end
