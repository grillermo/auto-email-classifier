# frozen_string_literal: true

require "test_helper"

class NtfyChannelTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "valid with channel and user" do
    ntfy = NtfyChannel.new(user: @user, channel: "my-topic")
    assert ntfy.valid?
  end

  test "invalid without channel" do
    ntfy = NtfyChannel.new(user: @user, channel: "")
    assert_not ntfy.valid?
  end

  test "notification_url returns full ntfy URL" do
    ntfy = NtfyChannel.new(user: @user, channel: "my-topic", server_url: "https://ntfy.sh")
    assert_equal "https://ntfy.sh/my-topic", ntfy.notification_url
  end
end
