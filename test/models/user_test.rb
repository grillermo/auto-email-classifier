# frozen_string_literal: true

require "test_helper"
require "omniauth"

class UserTest < ActiveSupport::TestCase
  def google_auth(email: "test@gmail.com", uid: "google-uid-123")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email }
    )
  end

  test "valid with email" do
    user = User.new(email: "test@example.com")
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(email: "")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with duplicate email" do
    User.create!(email: "dup@example.com")
    user = User.new(email: "dup@example.com")
    assert_not user.valid?
  end

  test "find_or_create_from_google creates new user with provider and uid" do
    assert_difference "User.count", 1 do
      user = User.find_or_create_from_google(google_auth)
      assert user.persisted?
      assert_equal "test@gmail.com", user.email
      assert_equal "google_oauth2", user.provider
      assert_equal "google-uid-123", user.uid
    end
  end

  test "find_or_create_from_google finds existing user by provider and uid" do
    existing = User.create!(email: "test@gmail.com", provider: "google_oauth2", uid: "google-uid-123")
    assert_no_difference "User.count" do
      user = User.find_or_create_from_google(google_auth)
      assert_equal existing.id, user.id
    end
  end

  test "find_or_create_from_google finds legacy user by email and backfills provider uid" do
    legacy = User.create!(email: "test@gmail.com")
    assert_nil legacy.provider
    assert_nil legacy.uid

    assert_no_difference "User.count" do
      user = User.find_or_create_from_google(google_auth(uid: "new-uid-456"))
      assert_equal legacy.id, user.id
    end

    legacy.reload
    assert_equal "google_oauth2", legacy.provider
    assert_equal "new-uid-456", legacy.uid
  end
end
