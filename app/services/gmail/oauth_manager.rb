# frozen_string_literal: true

module Gmail
  class OauthManager
    SCOPE = Gmail::Authorization::SCOPE

    def initialize(
      gmail_authentication:,
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"]
    )
      @gmail_authentication = gmail_authentication
      @client_id = client_id
      @client_secret = client_secret
    end

    def ensure_credentials!
      credentials = build_credentials
      credentials.fetch_access_token!

      gmail_authentication.update!(
        access_token: credentials.access_token,
        token_expires_at: credentials.expires_at,
        last_refreshed_at: Time.current
      )

      credentials
    rescue Signet::AuthorizationError => e
      gmail_authentication.update!(status: :needs_reauth)
      send_reauth_ntfy_notification
      raise
    end

    def activate!(credentials:, email:)
      gmail_authentication.update!(
        email: email,
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token.presence || gmail_authentication.refresh_token,
        token_expires_at: credentials.expires_at,
        last_refreshed_at: Time.current,
        status: :active,
        scopes: SCOPE
      )
    end

    private

    attr_reader :gmail_authentication, :client_id, :client_secret

    def build_credentials
      Google::Auth::UserRefreshCredentials.new(
        client_id: client_id,
        client_secret: client_secret,
        scope: SCOPE,
        access_token: gmail_authentication.access_token,
        refresh_token: gmail_authentication.refresh_token,
        expires_at: gmail_authentication.token_expires_at
      )
    end

    def send_reauth_ntfy_notification
      ntfy_channel = gmail_authentication.user.ntfy_channel
      return unless ntfy_channel&.channel.present?

      body = <<~BODY
        Gmail Re-Authorization Required

        The Gmail account #{gmail_authentication.email} needs to be re-authorized.
        Please sign in and click "Re-authorize" next to the account.
      BODY

      HTTP.post(ntfy_channel.notification_url, body: body)
    rescue StandardError => e
      Rails.logger.error("[OauthManager] ntfy notification failed: #{e.class} #{e.message}")
    end
  end
end
