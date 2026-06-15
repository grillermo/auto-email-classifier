require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  setup do
    host! "auto-email-classifier.chiq.me"
    @user = User.create!(email: "test@example.com")
  end

  test "health returns ok when every dependency is operational" do
    get "/health"

    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal true, payload["ok"]
    assert_equal true, payload.dig("checks", "database", "ok")
    assert_empty payload["checks"].values.flat_map { |check| check.keys & %w[error message] }
  end

  test "health returns service unavailable when a dependency fails" do
    HealthController.stub_any_instance(:check_database_connection, -> { raise ActiveRecord::ConnectionNotEstablished, "database unavailable" }) do
      get "/health"
    end

    assert_response :service_unavailable

    payload = JSON.parse(response.body)
    assert_equal false, payload["ok"]
    assert_equal false, payload.dig("checks", "database", "ok")
    assert_equal "ActiveRecord::ConnectionNotEstablished", payload.dig("checks", "database", "error")
  end

  test "health includes attached service checks" do
    queue_configuration = Struct.new(:name).new("queue")

    HealthController.stub_any_instance(:attached_database_configurations, [ queue_configuration ]) do
      HealthController.stub_any_instance(:check_database_configuration, true) do
        get "/health"
      end
    end

    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal true, payload.dig("checks", "queue", "ok")
  end

  test "oauth_debug shows the callback url and oauth client configuration in use" do
    sign_in(@user)

    original_app_base_url = ENV["APP_BASE_URL"]
    original_google_client_id = ENV["GOOGLE_CLIENT_ID"]
    original_route_defaults = Rails.application.routes.default_url_options
    original_mailer_defaults = Rails.application.config.action_mailer.default_url_options

    ENV["APP_BASE_URL"] = "https://auto-email-classifier.chiq.me"
    ENV["GOOGLE_CLIENT_ID"] = "test-client-id.apps.googleusercontent.com"
    Rails.application.routes.default_url_options = {
      host: "auto-email-classifier.chiq.me",
      protocol: "https"
    }
    Rails.application.config.action_mailer.default_url_options = {
      host: "auto-email-classifier.chiq.me",
      protocol: "https"
    }

    get "/health/oauth_debug"

    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal true, payload["ok"]
    assert_equal "https://auto-email-classifier.chiq.me", payload["app_base_url"]
    assert_equal "test-client-id.apps.googleusercontent.com", payload["google_client_id"]
    assert_equal "https://auto-email-classifier.chiq.me/gmail/oauth/callback", payload["oauth_callback_url"]
    assert_equal "https://auto-email-classifier.chiq.me/gmail/oauth/callback", payload["gcp_redirect_uri_to_register"]
  ensure
    ENV["APP_BASE_URL"] = original_app_base_url
    ENV["GOOGLE_CLIENT_ID"] = original_google_client_id
    Rails.application.routes.default_url_options = original_route_defaults
    Rails.application.config.action_mailer.default_url_options = original_mailer_defaults
  end
end
