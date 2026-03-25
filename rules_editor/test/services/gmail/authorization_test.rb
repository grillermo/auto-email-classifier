# frozen_string_literal: true

require "securerandom"
require "tmpdir"
require "test_helper"

class GmailAuthorizationTest < ActiveSupport::TestCase
  class FakeAuthorizer
    attr_reader :get_credentials_calls

    def initialize(credentials)
      @credentials = credentials
      @get_credentials_calls = 0
    end

    def get_credentials(_user_id)
      @get_credentials_calls += 1
      @credentials
    end
  end

  setup do
    Gmail::Authorization.clear_cache!
  end

  test "fetch_credentials memoizes credentials for repeated lookups" do
    authorization = build_authorization
    authorizer = FakeAuthorizer.new("token-1")

    authorization.define_singleton_method(:build_authorizer) { authorizer }
    assert_equal "token-1", authorization.fetch_credentials(user_id: Gmail::Authorization::USER_ID)
    assert_equal "token-1", authorization.fetch_credentials(user_id: Gmail::Authorization::USER_ID)

    assert_equal 1, authorizer.get_credentials_calls
  end

  test "credentials cache is shared across authorization instances" do
    first = build_authorization
    second = build_authorization
    first_authorizer = FakeAuthorizer.new("token-1")
    second_authorizer = FakeAuthorizer.new("token-2")

    first.define_singleton_method(:build_authorizer) { first_authorizer }
    assert_equal "token-1", first.fetch_credentials(user_id: Gmail::Authorization::USER_ID)

    second.define_singleton_method(:build_authorizer) { second_authorizer }
    assert_equal "token-1", second.fetch_credentials(user_id: Gmail::Authorization::USER_ID)

    assert_equal 1, first_authorizer.get_credentials_calls
    assert_equal 0, second_authorizer.get_credentials_calls
  end

  test "required_credentials raises when token file is missing" do
    missing_token_path = File.join(Dir.tmpdir, "gmail-token-#{SecureRandom.hex(8)}", "token.yaml")
    authorization = build_authorization(token_path: missing_token_path)

    error = assert_raises(RuntimeError) do
      authorization.required_credentials(user_id: Gmail::Authorization::USER_ID)
    end

    assert_equal Gmail::Authorization::CREDENTIALS_MISSING_MESSAGE, error.message
  end

  private

  def build_authorization(token_path: File.join(Dir.tmpdir, "gmail-token-cache", "token.yaml"))
    Gmail::Authorization.new(
      token_path: token_path,
      client_id: "test-client-id",
      client_secret: "test-client-secret"
    )
  end
end
