# frozen_string_literal: true

module Gmail
  class OauthManager
    OOB_URI = Gmail::Authorization::OOB_URI
    DEFAULT_TOKEN_PATH = Gmail::Authorization::DEFAULT_TOKEN_PATH
    USER_ID = Gmail::Authorization::USER_ID
    SCOPE = Gmail::Authorization::SCOPE

    def initialize(
      token_path: Gmail::Authorization.default_token_path,
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"]
    )
      @token_path = token_path
      @authorization = Gmail::Authorization.new(
        token_path: token_path,
        client_id: client_id,
        client_secret: client_secret,
        scope: SCOPE
      )
    end

    def ensure_credentials!
      credentials = authorization.fetch_credentials(user_id: USER_ID)
      if credentials
        begin
          credentials.fetch_access_token!
          return credentials
        rescue Signet::AuthorizationError => e
          puts "Cached credentials are no longer valid (#{e.message}). Please re-authenticate."
          delete_cached_token!
        end
      end

      perform_authentication(authorization.authorizer)
    end

    private

    attr_reader :authorization, :token_path

    def delete_cached_token!
      File.delete(token_path) if File.exist?(token_path)
      Gmail::Authorization.clear_cache!
    end

    def perform_authentication(authorizer)
      puts "=== Gmail OAuth 2.0 Setup (read and modify) ===\n",
           "Opening authorization URL in your browser...\n",
           "If the browser doesn't open automatically, please copy and paste this URL:"

      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts url, "\n"

      open_browser(url)

      puts "After authorizing, enter the authorization code:"
      code = $stdin.gets.to_s.strip
      raise "No authorization code received" if code.empty?

      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: USER_ID,
        code: code,
        base_url: OOB_URI
      )

      authorization.cache_credentials_for(user_id: USER_ID, credentials: credentials)
      credentials
    end

    def open_browser(url)
      case RUBY_PLATFORM
      when /darwin/
        system("open '#{url}'")
      when /linux/
        system("xdg-open '#{url}'")
      when /mingw|mswin/
        system("start '#{url}'")
      end
    end
  end
end
