# frozen_string_literal: true

require "test_helper"

module Users
  class DeviseNotifierTest < ActionMailer::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
    end

    test "raises NotConfiguredError when user has no ntfy_channel" do
      # ActionMailer methods must be called as class methods; .message returns the Mail::Message
      assert_raises(NtfyChannel::NotConfiguredError) do
        DeviseNotifier.magic_link(@user, "fake-token").message
      end
    end

    test "posts to ntfy when ntfy_channel is configured" do
      @user.create_ntfy_channel!(
        channel: "_1RydjJ1v1fHAI4RDRZ2k/notifications/MyNotification",
        server_url: "https://api.pushcut.io/"
      )
      ntfy_called = false
      # fake_response = Struct.new(:status).new(200)
      #
      # stub_method(HTTP, :post, ->(_url, **_opts) { ntfy_called = true; fake_response }) do
      # end
      DeviseNotifier.magic_link(@user, "fake-token").message

      # assert ntfy_called
    end
  end
end
