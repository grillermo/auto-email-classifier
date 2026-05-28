# frozen_string_literal: true

module Gmail
  class OauthCallbackController < ApplicationController
    OOB_URI = Gmail::Authorization::OOB_URI
    SCOPE   = Gmail::Authorization::SCOPE

    def new
      authorizer = build_authorizer
      url = authorizer.get_authorization_url(
        login_hint: current_user.email
      )
      redirect_to append_consent_prompt(url), allow_other_host: true
    end

    def create
      code = params.require(:code)
      authorizer = build_authorizer

      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: current_user.id.to_s,
        code: code
      )

      gmail_email = fetch_gmail_email(credentials)

      auth = current_user.gmail_authentications.find_or_initialize_by(email: gmail_email)
      existing_auth = auth.persisted?

      Gmail::OauthManager.new(gmail_authentication: auth).activate!(
        credentials: credentials,
        email: gmail_email
      )

      fetch_and_store_labels(auth, credentials)

      redirect_to root_path, notice: success_notice_for(gmail_email, existing_auth:)
    rescue ActionController::ParameterMissing, Google::Auth::AuthorizationError => e
      redirect_to root_path, alert: "Gmail authorization failed: #{e.message}"
    end

    private

    def build_authorizer
      client_id = Google::Auth::ClientId.new(
        ENV.fetch("GOOGLE_CLIENT_ID"),
        ENV.fetch("GOOGLE_CLIENT_SECRET")
      )
      token_store = Class.new do
        def load(_id) = nil
        def store(_id, _token) = nil
        def delete(_id) = nil
      end.new
      Google::Auth::UserAuthorizer.new(
        client_id,
        SCOPE,
        token_store,
        callback_uri: oauth_callback_url
      )
    end

    def fetch_and_store_labels(auth, credentials)
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = credentials
      response = service.list_user_labels("me")
      labels = Array(response.labels).map { |l| { "id" => l.id, "name" => l.name } }
      auth.update!(labels: labels)
    rescue StandardError => e
      Rails.logger.error("[OauthCallback] label fetch failed: #{e.class} #{e.message}")
    end

    def fetch_gmail_email(credentials)
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = credentials
      service.get_user_profile("me").email_address
    end

    def append_consent_prompt(url)
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query || "")
      params << ["prompt", "consent"]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def oauth_callback_url
      defaults = Rails.application.routes.default_url_options
      return gmail_oauth_callback_url if defaults.blank?

      gmail_oauth_callback_url(**defaults.symbolize_keys)
    end

    def success_notice_for(gmail_email, existing_auth:)
      return "Gmail account #{gmail_email} re-authorized." if existing_auth

      "Gmail account #{gmail_email} connected."
    end
  end
end
