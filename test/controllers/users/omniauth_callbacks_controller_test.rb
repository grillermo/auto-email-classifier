# frozen_string_literal: true

require "test_helper"
require "omniauth"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "auto-email-classifier.chiq.me"
    OmniAuth.config.test_mode = true
    # Ensure OmniAuth.config.path_prefix is set before the first request.
    # Devise sets it lazily when routes are drawn; force it here to avoid a
    # nil path_prefix causing on_callback_path? to return false.
    OmniAuth.config.path_prefix ||= "/users/auth"
    User.where(email: %w[new-user@gmail.com repeat-user@gmail.com legacy-user@gmail.com]).destroy_all
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:google_oauth2)
    Rails.application.env_config.delete("devise.mapping")
    OmniAuth.config.test_mode = false
    User.where(email: %w[new-user@gmail.com repeat-user@gmail.com legacy-user@gmail.com]).destroy_all
  end

  def set_google_auth(email: "user@gmail.com", uid: "g-uid-123", refresh_token: "ref-tok")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email },
      credentials: OmniAuth::AuthHash.new(
        token: "access-tok",
        refresh_token: refresh_token,
        expires_at: 1.hour.from_now.to_i
      )
    )
    Rails.application.env_config["devise.mapping"] = Devise.mappings[:user]
  end

  test "creates user and gmail_authentication on first Google sign-in" do
    set_google_auth(email: "new-user@gmail.com", uid: "g-uid-new")
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_difference ["User.count", "GmailAuthentication.count"], 1 do
        get "/users/auth/google_oauth2/callback"
      end
    end
    assert_response :redirect
    assert_redirected_to rules_path
    user = User.find_by(email: "new-user@gmail.com")
    assert user.present?
    assert_equal "google_oauth2", user.provider
    assert_equal "g-uid-new", user.uid
    assert GmailAuthentication.exists?(user: user, email: "new-user@gmail.com")
  end

  test "finds existing user by uid on repeat sign-in, no new records" do
    user = User.create!(email: "repeat-user@gmail.com", provider: "google_oauth2", uid: "g-uid-repeat")
    user.gmail_authentications.create!(
      email: "repeat-user@gmail.com",
      access_token: "old-tok",
      refresh_token: "old-ref"
    )

    set_google_auth(email: "repeat-user@gmail.com", uid: "g-uid-repeat")
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_no_difference ["User.count", "GmailAuthentication.count"] do
        get "/users/auth/google_oauth2/callback"
      end
    end
    assert_response :redirect
    assert_redirected_to rules_path
  end

  test "finds legacy user by email, backfills provider and uid" do
    legacy = User.create!(email: "legacy-user@gmail.com")
    legacy.gmail_authentications.create!(
      email: "legacy-user@gmail.com",
      access_token: "old-tok",
      refresh_token: "old-ref"
    )

    set_google_auth(email: "legacy-user@gmail.com", uid: "brand-new-uid")
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_no_difference "User.count" do
        get "/users/auth/google_oauth2/callback"
      end
    end

    legacy.reload
    assert_equal "google_oauth2", legacy.provider
    assert_equal "brand-new-uid", legacy.uid
  end
end
