# frozen_string_literal: true

require "test_helper"

class RulesShowTest < ActionDispatch::IntegrationTest
  test "shows matching emails with subject, from, date, and gmail link" do
    rule = Rule.create!(
      name: "Invoices",
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
      gmail_message_id: "gmail-1",
      rule_version: "v1",
      applied_at: Time.current,
      result: {
        message: {
          subject: "Invoice March",
          from: "billing@example.com",
          date: "Fri, 07 Mar 2026 13:20:00 +0000",
          thread_id: "thread-1"
        }
      }
    )

    get rule_path(rule), headers: inertia_headers

    assert_response :success

    payload = JSON.parse(response.body)
    matching_email = payload.dig("props", "matchingEmails", "emails", 0)

    assert_equal "Rules/Show", payload["component"]
    assert_equal 1, payload.dig("props", "matchingEmails", "totalCount")
    assert_equal "Invoice March", matching_email.fetch("subject")
    assert_equal "billing@example.com", matching_email.fetch("from")
    assert_equal "https://mail.google.com/mail/u/0/#all/thread-1", matching_email.fetch("gmailUrl")
  end

  private

  def inertia_headers
    { "X-Inertia" => "true" }
  end
end
