# frozen_string_literal: true

require "test_helper"

module Gmail
  class TokenValidatorTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
      @auth = GmailAuthentication.create!(
        user: @user,
        email: "gmail@example.com",
        access_token: "tok",
        refresh_token: "ref",
        token_expires_at: 1.hour.from_now
      )
    end

    test "refreshes active tokens and returns needs_reauth list" do
      fake_creds = Struct.new(:access_token, :expires_at) { def fetch_access_token!; end }.new("new-tok", 2.hours.from_now)

      OauthManager.stub_any_instance(:build_credentials, fake_creds) do
        result = TokenValidator.call(user: @user)
        assert_empty result[:needs_reauth]
      end
    end

    test "returns needs_reauth when token refresh fails" do
      error_creds = Object.new.tap do |obj|
        obj.define_singleton_method(:fetch_access_token!) { raise Signet::AuthorizationError.new("revoked") }
      end

      OauthManager.stub_any_instance(:build_credentials, error_creds) do
        result = TokenValidator.call(user: @user)
        assert_includes result[:needs_reauth], @auth.email
      end
    end

    test "skips needs_reauth accounts" do
      @auth.update!(status: :needs_reauth)
      result = TokenValidator.call(user: @user)
      assert_empty result[:needs_reauth]
    end
  end
end
