# frozen_string_literal: true

require "test_helper"

module Slack
  class ReauthNotifierTest < ActiveSupport::TestCase
    setup do
      @prev_webhook = ENV["SLACK_REAUTH_WEBHOOK_URL"]
      ENV["SLACK_REAUTH_WEBHOOK_URL"] = "https://hooks.slack.test/abc"
      @prev_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
    end

    teardown do
      ENV["SLACK_REAUTH_WEBHOOK_URL"] = @prev_webhook
      Rails.cache = @prev_cache
    end

    def build_auth(email:)
      user = User.create!(email: email)
      GmailAuthentication.create!(
        user: user,
        email: "gmail+#{user.id}@example.com",
        access_token: "old-access",
        refresh_token: "valid-refresh",
        token_expires_at: 1.minute.from_now
      )
    end

    def notify(auth, posted)
      stub_method(HTTP, :post, ->(url, **opts) { posted << [ url, opts ]; Struct.new(:status).new(200) }) do
        ReauthNotifier.new(gmail_authentication: auth).call
      end
    end

    test "posts the first notification" do
      auth = build_auth(email: "first@example.com")
      posted = []

      notify(auth, posted)

      assert_equal 1, posted.size
    end

    test "skips repeat notifications inside the throttle window" do
      auth = build_auth(email: "repeat@example.com")
      posted = []

      3.times { notify(auth, posted) }

      assert_equal 1, posted.size
    end

    test "posts again once the throttle window has passed" do
      auth = build_auth(email: "later@example.com")
      posted = []

      notify(auth, posted)
      travel (ReauthNotifier::THROTTLE_WINDOW + 1.second) do
        notify(auth, posted)
      end

      assert_equal 2, posted.size
    end

    test "throttles each account independently" do
      one = build_auth(email: "one@example.com")
      two = build_auth(email: "two@example.com")
      posted = []

      notify(one, posted)
      notify(two, posted)

      assert_equal 2, posted.size
    end

    test "does not consume the throttle window when no webhook is configured" do
      ENV["SLACK_REAUTH_WEBHOOK_URL"] = nil
      auth = build_auth(email: "nowebhook@example.com")
      posted = []

      notify(auth, posted)
      assert_empty posted

      ENV["SLACK_REAUTH_WEBHOOK_URL"] = "https://hooks.slack.test/abc"
      notify(auth, posted)
      assert_equal 1, posted.size
    end
  end
end
