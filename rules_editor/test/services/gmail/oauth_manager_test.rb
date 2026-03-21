# frozen_string_literal: true

require "test_helper"

module Gmail
  class OauthManagerTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
      @auth = GmailAuthentication.create!(
        user: @user,
        email: "gmail@example.com",
        access_token: "old-access",
        refresh_token: "valid-refresh",
        token_expires_at: 1.hour.from_now
      )
    end

    test "ensure_credentials! returns credentials when token is valid" do
      mock_credentials = Minitest::Mock.new
      mock_credentials.expect(:fetch_access_token!, nil)
      mock_credentials.expect(:access_token, "new-access")
      mock_credentials.expect(:expires_at, 2.hours.from_now)

      OauthManager.stub_any_instance(:build_credentials, mock_credentials) do
        manager = OauthManager.new(gmail_authentication: @auth)
        result = manager.ensure_credentials!
        assert_equal mock_credentials, result
      end

      @auth.reload
      assert_equal "new-access", @auth.access_token
    end

    test "ensure_credentials! marks needs_reauth on AuthorizationError" do
      mock_credentials = Minitest::Mock.new
      mock_credentials.expect(:fetch_access_token!, nil) { raise Signet::AuthorizationError.new("revoked") }

      OauthManager.stub_any_instance(:build_credentials, mock_credentials) do
        manager = OauthManager.new(gmail_authentication: @auth)
        assert_raises(Signet::AuthorizationError) { manager.ensure_credentials! }
      end

      assert @auth.reload.status_needs_reauth?
    end

    test "ensure_credentials! sends ntfy notification on auth error when channel configured" do
      @user.create_ntfy_channel!(channel: "test-topic")
      mock_credentials = Minitest::Mock.new
      mock_credentials.expect(:fetch_access_token!, nil) { raise Signet::AuthorizationError.new("revoked") }

      ntfy_called = false
      HTTP.stub(:post, ->(_url, **_opts) { ntfy_called = true; Struct.new(:status).new(200) }) do
        OauthManager.stub_any_instance(:build_credentials, mock_credentials) do
          manager = OauthManager.new(gmail_authentication: @auth)
          assert_raises(Signet::AuthorizationError) { manager.ensure_credentials! }
        end
      end

      assert ntfy_called
    end
  end
end
