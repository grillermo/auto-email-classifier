# frozen_string_literal: true

module Slack
  # Posts a Slack message with a one-click re-authentication link when a Gmail
  # account fails to re-authenticate. Clicking the link lands on the Google
  # sign-in page; signing in re-activates the account via upsert_from_google.
  #
  # ProcessCycleJob retries reauth every minute, so notifications are throttled
  # to one per account per THROTTLE_WINDOW.
  class ReauthNotifier
    THROTTLE_WINDOW = 5.minutes

    def initialize(gmail_authentication:)
      @gmail_authentication = gmail_authentication
    end

    def call
      webhook_url = ENV["SLACK_REAUTH_WEBHOOK_URL"]
      return if webhook_url.blank?
      return if throttled?

      HTTP.post(webhook_url, json: { text: message })
    rescue StandardError => e
      Rails.logger.error("[Slack::ReauthNotifier] post failed: #{e.class} #{e.message}")
    end

    private

    attr_reader :gmail_authentication

    # Claims the window for this account. Returns true when another
    # notification already claimed it, meaning we stay quiet this cycle.
    def throttled?
      return true if Rails.cache.read(throttle_key).present?

      Rails.cache.write(throttle_key, Time.current.to_i, expires_in: THROTTLE_WINDOW)
      false
    end

    def throttle_key
      "slack/reauth_notifier/#{gmail_authentication.id}"
    end

    def message
      "Reauthentication failure for #{gmail_authentication.email}, " \
        "<#{reauth_link}|click here to re-authenticate>"
    end

    def reauth_link
      helpers = Rails.application.routes.url_helpers
      defaults = Rails.application.routes.default_url_options
      return helpers.new_user_session_url(**defaults.symbolize_keys) if defaults[:host].present?

      helpers.new_user_session_url(host: "localhost", port: 3000)
    end
  end
end
