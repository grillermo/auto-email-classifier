# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
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
end
