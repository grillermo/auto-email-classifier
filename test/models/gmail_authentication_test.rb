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

  # --- upsert_from_google tests ---

  require "omniauth"

  def google_auth(email: "user@gmail.com", uid: "g-uid-1", refresh_token: "ref-tok")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email },
      credentials: OmniAuth::AuthHash.new(
        token: "access-tok",
        refresh_token: refresh_token,
        expires_at: 1.hour.from_now.to_i
      )
    )
  end

  test "upsert_from_google creates new GmailAuthentication" do
    user = User.create!(email: "user@gmail.com", provider: "google_oauth2", uid: "g-uid-1")
    auth = google_auth

    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_difference "GmailAuthentication.count", 1 do
        ga = GmailAuthentication.upsert_from_google(user: user, auth: auth)
        assert ga.persisted?
        assert_equal "user@gmail.com", ga.email
        assert_equal "access-tok", ga.access_token
        assert_equal "ref-tok", ga.refresh_token
        assert ga.status_active?
      end
    end
  end

  test "upsert_from_google updates existing GmailAuthentication with fresh tokens" do
    user = User.create!(email: "user@gmail.com", provider: "google_oauth2", uid: "g-uid-1")
    user.gmail_authentications.create!(
      email: "user@gmail.com",
      access_token: "old-access",
      refresh_token: "old-refresh"
    )

    auth = google_auth(refresh_token: "new-refresh")
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_no_difference "GmailAuthentication.count" do
        ga = GmailAuthentication.upsert_from_google(user: user, auth: auth)
        assert_equal "access-tok", ga.access_token
        assert_equal "new-refresh", ga.refresh_token
      end
    end
  end

  test "upsert_from_google does not overwrite refresh_token when omitted" do
    user = User.create!(email: "user@gmail.com", provider: "google_oauth2", uid: "g-uid-1")
    user.gmail_authentications.create!(
      email: "user@gmail.com",
      access_token: "old-access",
      refresh_token: "keep-this"
    )

    auth = google_auth(refresh_token: nil)
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      ga = GmailAuthentication.upsert_from_google(user: user, auth: auth)
      assert_equal "keep-this", ga.refresh_token
    end
  end
end
