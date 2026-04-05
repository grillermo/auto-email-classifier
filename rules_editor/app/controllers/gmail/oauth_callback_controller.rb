# frozen_string_literal: true

module Gmail
  class OauthCallbackController < ApplicationController
    OOB_URI = Gmail::Authorization::OOB_URI
    SCOPE   = Gmail::Authorization::SCOPE

    def new
      authorizer = build_authorizer
      url = authorizer.get_authorization_url(
        base_url: oauth_callback_url,
        login_hint: current_user.email
      )
      redirect_to url, allow_other_host: true
    end

    def create
      code = params.require(:code)
      authorizer = build_authorizer

      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: current_user.id.to_s,
        code: code,
        base_url: oauth_callback_url
      )

      gmail_email = fetch_gmail_email(credentials)

      auth = current_user.gmail_authentications.find_or_initialize_by(email: gmail_email)
      existing_auth = auth.persisted?

      Gmail::OauthManager.new(gmail_authentication: auth).activate!(
        credentials: credentials,
        email: gmail_email
      )

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
      Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    end

    def fetch_gmail_email(credentials)
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = credentials
      service.get_user_profile("me").email_address
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
