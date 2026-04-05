# frozen_string_literal: true

app_base_url = ENV["APP_BASE_URL"].to_s.strip

unless app_base_url.empty?
  uri = URI.parse(app_base_url)
  default_url_options = {
    host: uri.host,
    protocol: uri.scheme
  }

  default_url_options[:port] = uri.port unless [80, 443].include?(uri.port)
  default_url_options[:script_name] = uri.path unless uri.path.blank? || uri.path == "/"

  Rails.application.routes.default_url_options = default_url_options.dup
  Rails.application.config.action_mailer.default_url_options = default_url_options.dup
end
