# frozen_string_literal: true

require "test_helper"

class GmailAuthenticationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "valid with required fields" do
    auth = GmailAuthentication.new(user: @user, email: "gmail@example.com")
    assert auth.valid?
  end

  test "invalid without email" do
    auth = GmailAuthentication.new(user: @user, email: "")
    assert_not auth.valid?
  end

  test "invalid with duplicate email for same user" do
    GmailAuthentication.create!(user: @user, email: "gmail@example.com")
    auth = GmailAuthentication.new(user: @user, email: "gmail@example.com")
    assert_not auth.valid?
  end

  test "same email allowed for different users" do
    other_user = User.create!(email: "other@example.com")
    GmailAuthentication.create!(user: @user, email: "shared@gmail.com")
    auth = GmailAuthentication.new(user: other_user, email: "shared@gmail.com")
    assert auth.valid?
  end

  test "status defaults to active" do
    auth = GmailAuthentication.create!(user: @user, email: "gmail@example.com")
    assert auth.status_active?
  end

  test "encrypts access_token and refresh_token" do
    auth = GmailAuthentication.create!(
      user: @user,
      email: "gmail@example.com",
      access_token: "secret-access",
      refresh_token: "secret-refresh"
    )
    # Raw DB value should not be the plain-text token
    raw = ActiveRecord::Base.connection.execute(
      "SELECT access_token FROM gmail_authentications WHERE id = '#{auth.id}'"
    ).first["access_token"]
    assert_not_equal "secret-access", raw
    # Model returns decrypted value
    assert_equal "secret-access", auth.reload.access_token
  end
end
