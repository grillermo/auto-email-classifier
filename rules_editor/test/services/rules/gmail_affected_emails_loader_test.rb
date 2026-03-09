# frozen_string_literal: true

require "test_helper"

class RulesGmailAffectedEmailsLoaderTest < ActiveSupport::TestCase
  class FakeGmailClient
    attr_reader :last_query, :last_max_results

    def initialize(message_ids:, messages:, errors: {})
      @message_ids = message_ids
      @messages = messages
      @errors = errors
    end

    def list_message_ids(query:, max_results:)
      @last_query = query
      @last_max_results = max_results
      message_ids.take(max_results)
    end

    def fetch_normalized_message(message_id)
      raise(errors[message_id]) if errors.key?(message_id)

      messages.fetch(message_id)
    end

    private

    attr_reader :message_ids, :messages, :errors
  end

  test "returns only emails the rule would still apply to" do
    rule = Rule.create!(
      name: "Billing",
      active: true,
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "already-applied",
      rule_version: rule.version_digest,
      result: {},
      applied_at: Time.current
    )

    gmail_client = FakeGmailClient.new(
      message_ids: %w[already-applied match-1 no-match match-2],
      messages: {
        "already-applied" => message_payload(id: "already-applied", sender: "billing@example.com", subject: "Invoice 1"),
        "match-1" => message_payload(id: "match-1", sender: "billing@example.com", subject: "Invoice 2"),
        "no-match" => message_payload(id: "no-match", sender: "noreply@example.com", subject: "Status"),
        "match-2" => message_payload(id: "match-2", sender: "billing@example.com", subject: "Invoice 3")
      }
    )

    result = Rules::GmailAffectedEmailsLoader.new(
      rule: rule,
      gmail_client_factory: -> { gmail_client },
      max_messages_scanned: 50,
      max_displayed_emails: 10
    ).load

    assert_equal "in:inbox", gmail_client.last_query
    assert_equal 50, gmail_client.last_max_results
    assert_equal 4, result[:scanned_count]
    assert_equal 2, result[:total_count]
    assert_equal false, result[:truncated]
    assert_nil result[:error]
    assert_equal %w[match-1 match-2], result[:emails].map { |email| email[:email_id] }
    assert_equal ["mark_read"], result[:emails].first[:actions]
  end

  test "keeps partial results when some Gmail messages fail to load" do
    rule = Rule.create!(
      name: "Invoices",
      active: true,
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "subject", operator: "contains", value: "Invoice" }],
        actions: [{ type: "mark_read" }]
      }
    )

    gmail_client = FakeGmailClient.new(
      message_ids: %w[broken match-1 match-2 match-3],
      messages: {
        "match-1" => message_payload(id: "match-1", sender: "a@example.com", subject: "Invoice A"),
        "match-2" => message_payload(id: "match-2", sender: "b@example.com", subject: "Invoice B"),
        "match-3" => message_payload(id: "match-3", sender: "c@example.com", subject: "Invoice C")
      },
      errors: { "broken" => "temporary Gmail error" }
    )

    result = Rules::GmailAffectedEmailsLoader.new(
      rule: rule,
      gmail_client_factory: -> { gmail_client },
      max_displayed_emails: 2
    ).load

    assert_equal 4, result[:scanned_count]
    assert_equal 3, result[:total_count]
    assert_equal 2, result[:emails].length
    assert_equal true, result[:truncated]
    assert_equal "temporary Gmail error", result[:error]
  end

  private

  def message_payload(id:, sender:, subject:)
    {
      id: id,
      thread_id: "thread-#{id}",
      date: "Fri, 07 Mar 2026 13:20:00 +0000",
      from: sender,
      subject: subject,
      body: "Body"
    }
  end
end
