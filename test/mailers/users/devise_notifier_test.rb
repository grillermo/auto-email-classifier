# frozen_string_literal: true

require "test_helper"
require "json"
require "uri"

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
        magic_link_uri = URI.parse(payload["input"])
        magic_link_params = Rack::Utils.parse_nested_query(magic_link_uri.query)

        test_case.assert_equal "Sign in link", payload["title"]
        test_case.assert_equal "http://localhost/users/magic_link", "#{magic_link_uri.scheme}://#{magic_link_uri.host}#{magic_link_uri.path}"
        test_case.assert_equal(
          {
            "email" => "test@example.com",
            "token" => "fake-token",
            "remember_me" => "false"
          },
          magic_link_params.fetch("user")
        )
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
