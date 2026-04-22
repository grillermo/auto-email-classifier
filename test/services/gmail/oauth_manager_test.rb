# frozen_string_literal: true

require "test_helper"

module Gmail
  class OauthManagerTest < ActiveSupport::TestCase
    FakeCredentials = Struct.new(:access_token, :expires_at) do
      def fetch_access_token!; end
    end

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
      fake_creds = FakeCredentials.new("new-access", 2.hours.from_now)

      OauthManager.stub_any_instance(:build_credentials, fake_creds) do
        manager = OauthManager.new(gmail_authentication: @auth)
        result = manager.ensure_credentials!
        assert_equal fake_creds, result
      end

      @auth.reload
      assert_equal "new-access", @auth.access_token
    end

    test "ensure_credentials! marks needs_reauth on AuthorizationError" do
      error_creds = Object.new.tap do |obj|
        obj.define_singleton_method(:fetch_access_token!) { raise Signet::AuthorizationError.new("revoked") }
      end

      OauthManager.stub_any_instance(:build_credentials, error_creds) do
        manager = OauthManager.new(gmail_authentication: @auth)
        assert_raises(Signet::AuthorizationError) { manager.ensure_credentials! }
      end

      assert @auth.reload.status_needs_reauth?
    end

    test "ensure_credentials! sends ntfy notification on auth error when channel configured" do
      @user.create_ntfy_channel!(channel: "test-topic", server_url: "https://ntfy.sh")
      error_creds = Object.new.tap do |obj|
        obj.define_singleton_method(:fetch_access_token!) { raise Signet::AuthorizationError.new("revoked") }
      end

      ntfy_called = false
      stub_method(HTTP, :post, ->(_url, **_opts) { ntfy_called = true; Struct.new(:status).new(200) }) do
        OauthManager.stub_any_instance(:build_credentials, error_creds) do
          manager = OauthManager.new(gmail_authentication: @auth)
          assert_raises(Signet::AuthorizationError) { manager.ensure_credentials! }
        end
      end

      assert ntfy_called
    end

    test "activate! updates tokens and marks the authentication active" do
      credentials = Struct.new(:access_token, :refresh_token, :expires_at).new(
        "new-access",
        "new-refresh",
        2.hours.from_now
      )

      OauthManager.new(gmail_authentication: @auth).activate!(
        credentials: credentials,
        email: "gmail@example.com"
      )

      @auth.reload
      assert_equal "new-access", @auth.access_token
      assert_equal "new-refresh", @auth.refresh_token
      assert @auth.status_active?
      assert_equal Gmail::Authorization::SCOPE, @auth.scopes
    end

    test "activate! preserves an existing refresh token when credentials omit one" do
      @auth.update!(status: :needs_reauth)
      credentials = Struct.new(:access_token, :refresh_token, :expires_at).new(
        "fresh-access",
        nil,
        2.hours.from_now
      )

      OauthManager.new(gmail_authentication: @auth).activate!(
        credentials: credentials,
        email: "gmail@example.com"
      )

      @auth.reload
      assert_equal "fresh-access", @auth.access_token
      assert_equal "valid-refresh", @auth.refresh_token
      assert @auth.status_active?
    end
  end
end
