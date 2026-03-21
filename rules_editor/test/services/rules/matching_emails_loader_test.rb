# frozen_string_literal: true

require "test_helper"

class RulesMatchingEmailsLoaderTest < ActiveSupport::TestCase
  def create_rule
    Rule.create!(
      name: "Billing",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  def create_application(rule:, message_id:, subject: "Invoice", from: "billing@example.com", date: "Mon, 10 Mar 2026 09:00:00 +0000", thread_id: nil)
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: message_id,
      rule_version: rule.version_digest,
      applied_at: Time.current,
      result: {
        message: {
          subject: subject,
          from: from,
          date: date,
          thread_id: thread_id
        }.compact
      }
    )
  end

  test "returns empty result when rule has no applications" do
    rule = create_rule
    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal 0, result[:total_count]
    assert_equal [], result[:emails]
    assert_equal false, result[:truncated]
    assert_nil result[:error]
  end

  test "loads emails from rule_applications with complete metadata" do
    rule = create_rule
    create_application(rule: rule, message_id: "msg-1", thread_id: "thread-1")

    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal 1, result[:total_count]
    email = result[:emails].first
    assert_equal "Invoice", email[:subject]
    assert_equal "billing@example.com", email[:from]
    assert_equal "https://mail.google.com/mail/u/0/#all/thread-1", email[:gmail_url]
  end

  test "gmail_url falls back to message_id when thread_id is absent" do
    rule = create_rule
    create_application(rule: rule, message_id: "msg-2")

    result = Rules::MatchingEmailsLoader.new(rule: rule).load
    email = result[:emails].first

    assert_equal "https://mail.google.com/mail/u/0/#all/msg-2", email[:gmail_url]
  end

  test "deduplicates by gmail_message_id" do
    rule = create_rule
    create_application(rule: rule, message_id: "msg-dup")
    # Apply same message again with different rule version
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-dup",
      rule_version: "different-version",
      applied_at: 1.hour.ago,
      result: { message: { subject: "Old", from: "billing@example.com", date: "Mon, 01 Jan 2024 00:00:00 +0000" } }
    )

    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal 1, result[:emails].length
    assert_equal 1, result[:total_count]
  end

  test "fetches missing metadata from Gmail when subject or from is blank" do
    rule = create_rule
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-no-meta",
      rule_version: rule.version_digest,
      applied_at: Time.current,
      result: { message: {} }  # no subject/from/date stored
    )

    fake_gmail = Class.new do
      def fetch_normalized_message(id)
        { subject: "From Gmail", from: "billing@example.com", date: "Tue, 01 Apr 2025 12:00:00 +0000", thread_id: nil }
      end
    end.new

    result = Rules::MatchingEmailsLoader.new(rule: rule, gmail_client_factory: -> { fake_gmail }).load
    email = result[:emails].first

    assert_equal "From Gmail", email[:subject]
  end

  test "captures Gmail fetch error and continues with placeholder text" do
    rule = create_rule
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-broken",
      rule_version: rule.version_digest,
      applied_at: Time.current,
      result: { message: {} }
    )

    failing_gmail = Class.new do
      def fetch_normalized_message(_id)
        raise StandardError, "Gmail unavailable"
      end
    end.new

    result = Rules::MatchingEmailsLoader.new(rule: rule, gmail_client_factory: -> { failing_gmail }).load

    assert_equal "Gmail unavailable", result[:error]
    email = result[:emails].first
    assert_equal "(subject unavailable)", email[:subject]
    assert_equal "(sender unavailable)", email[:from]
  end

  test "truncated is true when unique message count exceeds MAX_DISPLAYED_EMAILS" do
    rule = create_rule
    # Create 51 unique applications
    51.times do |i|
      create_application(rule: rule, message_id: "msg-#{i}")
    end

    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal true, result[:truncated]
    assert_equal 50, result[:emails].length
    assert_equal 51, result[:total_count]
  end
end
