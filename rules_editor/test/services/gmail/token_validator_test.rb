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
      mock_creds = Minitest::Mock.new
      mock_creds.expect(:fetch_access_token!, nil)
      mock_creds.expect(:access_token, "new-tok")
      mock_creds.expect(:expires_at, 2.hours.from_now)

      OauthManager.stub_any_instance(:build_credentials, mock_creds) do
        result = TokenValidator.call(user: @user)
        assert_empty result[:needs_reauth]
      end
    end

    test "returns needs_reauth when token refresh fails" do
      mock_creds = Minitest::Mock.new
      mock_creds.expect(:fetch_access_token!, nil) { raise Signet::AuthorizationError.new("revoked") }

      OauthManager.stub_any_instance(:build_credentials, mock_creds) do
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
