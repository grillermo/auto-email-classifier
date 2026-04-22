# frozen_string_literal: true

class HealthController < ApplicationController
  def test_google_credentials
    profile = Gmail::Client.new.profile

    render json: {
      ok: true,
      email_address: profile.email_address,
      messages_total: profile.messages_total,
      threads_total: profile.threads_total
    }
  rescue StandardError => e
    render json: {
      ok: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  def oauth_debug
    render json: {
      ok: true,
      app_base_url: ENV["APP_BASE_URL"],
      google_client_id: ENV["GOOGLE_CLIENT_ID"],
      route_default_url_options: Rails.application.routes.default_url_options,
      action_mailer_default_url_options: Rails.application.config.action_mailer.default_url_options,
      request_base_url: request.base_url,
      request_host: request.host,
      request_protocol: request.protocol,
      oauth_callback_url: oauth_callback_url,
      gcp_redirect_uri_to_register: oauth_callback_url
    }
  rescue StandardError => e
    render json: {
      ok: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  private

  def oauth_callback_url
    defaults = Rails.application.routes.default_url_options
    return gmail_oauth_callback_url if defaults.blank?

    gmail_oauth_callback_url(**defaults.symbolize_keys)
  end
end
