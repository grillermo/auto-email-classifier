# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_user!, only: :show

  def show
    checks = health_checks
    ok = checks.values.all? { |check| check[:ok] }

    render json: {
      ok: ok,
      checks: checks
    }, status: ok ? :ok : :service_unavailable
  end

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

  def health_checks
    {
      database: check_dependency { check_database_connection }
    }.merge(attached_service_checks)
  end

  def attached_service_checks
    attached_database_configurations.to_h do |configuration|
      [
        configuration.name.to_sym,
        check_dependency { check_database_configuration(configuration) }
      ]
    end
  end

  def attached_database_configurations
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).filter_map do |configuration|
      configuration if %w[cache queue cable].include?(configuration.name)
    end
  end

  def check_dependency
    yield
    { ok: true }
  rescue StandardError => e
    {
      ok: false,
      error: e.class.name,
      message: e.message
    }
  end

  def check_database_connection
    ActiveRecord::Base.connection.execute("SELECT 1")
  end

  def check_database_configuration(configuration)
    connection_class = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
    end
    connection_class.define_singleton_method(:name) { "HealthCheck#{configuration.name.camelize}Record" }

    connection_class.establish_connection(configuration.configuration_hash)
    connection_class.connection.execute("SELECT 1")
  ensure
    connection_class&.connection_pool&.disconnect!
  end

  def oauth_callback_url
    defaults = Rails.application.routes.default_url_options
    return gmail_oauth_callback_url if defaults.blank?

    gmail_oauth_callback_url(**defaults.symbolize_keys)
  end
end
