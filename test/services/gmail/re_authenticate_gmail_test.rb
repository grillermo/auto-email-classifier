# frozen_string_literal: true

require "test_helper"

module Gmail
  class ReAuthenticateGmailTest < ActiveSupport::TestCase
    setup do
      @target_user = User.create!(email: "guillermo.siliceo@gmail.com")
      @other_user = User.create!(email: "someone.else@example.com")
      @prev_webhook = ENV["SLACK_REAUTH_WEBHOOK_URL"]
      ENV["SLACK_REAUTH_WEBHOOK_URL"] = "https://hooks.slack.test/abc"
    end

    teardown do
      ENV["SLACK_REAUTH_WEBHOOK_URL"] = @prev_webhook
    end

    def build_auth(user)
      GmailAuthentication.create!(
        user: user,
        email: "gmail+#{user.id}@example.com",
        access_token: "old-access",
        refresh_token: "valid-refresh",
        token_expires_at: 1.minute.from_now
      )
    end

    test "notifies Slack on auth failure for a target user" do
      auth = build_auth(@target_user)
      posted = []

      OauthManager.stub_any_instance(:ensure_credentials!, ->(*) { raise Signet::AuthorizationError.new("revoked") }) do
        stub_method(HTTP, :post, ->(url, **opts) { posted << [url, opts]; Struct.new(:status).new(200) }) do
          ReAuthenticateGmail.new(authentications: [auth]).call
        end
      end

      assert_equal 1, posted.size
      url, opts = posted.first
      assert_equal "https://hooks.slack.test/abc", url
      assert_includes opts.dig(:json, :text), "click here to re-authenticate"
      assert_includes opts.dig(:json, :text), auth.email
    end

    test "does not notify Slack for non-target users" do
      auth = build_auth(@other_user)
      posted = []

      OauthManager.stub_any_instance(:ensure_credentials!, ->(*) { raise Signet::AuthorizationError.new("revoked") }) do
        stub_method(HTTP, :post, ->(url, **opts) { posted << [url, opts]; Struct.new(:status).new(200) }) do
          ReAuthenticateGmail.new(authentications: [auth]).call
        end
      end

      assert_empty posted
    end

    test "reactivates on success without notifying" do
      auth = build_auth(@target_user)
      posted = []

      OauthManager.stub_any_instance(:ensure_credentials!, ->(*) { true }) do
        stub_method(HTTP, :post, ->(url, **opts) { posted << [url, opts]; Struct.new(:status).new(200) }) do
          ReAuthenticateGmail.new(authentications: [auth]).call
        end
      end

      assert auth.reload.status_active?
      assert_empty posted
    end
  end
end
