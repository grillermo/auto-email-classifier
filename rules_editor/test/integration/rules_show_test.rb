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

    get rule_path(rule)

    assert_response :success
    assert_select "h2", text: "Matching Emails (1)"
    assert_select "td", text: "Invoice March"
    assert_select "td", text: "billing@example.com"
    assert_select "a[href='https://mail.google.com/mail/u/0/#all/thread-1']", text: "Open in Gmail"
  end
end
