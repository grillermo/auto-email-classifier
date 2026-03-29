# frozen_string_literal: true

require "test_helper"
require "json"

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
        server_url: "https://api.pushcut.io"
      )
      test_case = self
      ntfy_called = false
      fake_response = Struct.new(:status).new(200)
      expected_url = "https://api.pushcut.io/_1RydjJ1v1fHAI4RDRZ2k/notifications/MyNotification"

      fake_http = Object.new
      fake_http.define_singleton_method(:post) do |url, **opts|
        ntfy_called = true
        test_case.assert_equal expected_url, url

        payload = JSON.parse(opts.fetch(:body))
        test_case.assert_equal "Sign in link", payload["title"]
        test_case.assert_equal "http://localhost/users/magic_link?token=fake-token", payload["input"]
        test_case.assert_includes payload["text"], "Sign in to Auto Email Classifier"
        test_case.assert_includes payload["text"], payload["input"]

        fake_response
      end

      stub_method(HTTP, :headers, fake_http) do
        DeviseNotifier.magic_link(@user, "fake-token").message
      end

      assert ntfy_called
    end
  end
end
