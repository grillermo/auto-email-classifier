# frozen_string_literal: true

module Slack
  # Posts a Slack message with a one-click re-authentication link when a Gmail
  # account fails to re-authenticate. Clicking the link lands on the Google
  # sign-in page; signing in re-activates the account via upsert_from_google.
  class ReauthNotifier
    def initialize(gmail_authentication:)
      @gmail_authentication = gmail_authentication
    end

    def call
      webhook_url = ENV["SLACK_REAUTH_WEBHOOK_URL"]
      return if webhook_url.blank?

      HTTP.post(webhook_url, json: { text: message })
    rescue StandardError => e
      Rails.logger.error("[Slack::ReauthNotifier] post failed: #{e.class} #{e.message}")
    end

    private

    attr_reader :gmail_authentication

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
