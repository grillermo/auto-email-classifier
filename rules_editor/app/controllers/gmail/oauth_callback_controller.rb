# frozen_string_literal: true

module Gmail
  class OauthCallbackController < ApplicationController
    OOB_URI = Gmail::Authorization::OOB_URI
    SCOPE   = Gmail::Authorization::SCOPE

    def new
      authorizer = build_authorizer
      url = authorizer.get_authorization_url(base_url: gmail_oauth_callback_url)
      redirect_to url, allow_other_host: true
    end

    def create
      code = params.require(:code)
      authorizer = build_authorizer

      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: current_user.id.to_s,
        code: code,
        base_url: gmail_oauth_callback_url
      )

      gmail_email = fetch_gmail_email(credentials)

      auth = current_user.gmail_authentications.find_or_initialize_by(email: gmail_email)
      auth.update!(
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token,
        token_expires_at: credentials.expires_at,
        last_refreshed_at: Time.current,
        status: :active,
        scopes: SCOPE
      )

      redirect_to root_path, notice: "Gmail account #{gmail_email} connected."
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
  end
end
