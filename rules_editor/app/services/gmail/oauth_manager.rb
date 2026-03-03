# frozen_string_literal: true

require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "uri"

module Gmail
  class OauthManager
    USER_ID = "default"
    SCOPES = [
      "https://www.googleapis.com/auth/gmail.modify",
      "https://www.googleapis.com/auth/gmail.send",
      "https://www.googleapis.com/auth/gmail.readonly"
    ].freeze

    def initialize(
      client_path: ENV.fetch("GOOGLE_OAUTH_CLIENT_PATH", Rails.root.join("config", "google_oauth_client.json").to_s),
      token_path: ENV.fetch("GOOGLE_OAUTH_TOKEN_PATH", Rails.root.join("tmp", "gmail_token.json").to_s)
    )
      @client_path = client_path
      @token_path = token_path
    end

    def ensure_credentials!
      validate_client_path!
      FileUtils.mkdir_p(File.dirname(token_path))

      credentials = authorizer.get_credentials(USER_ID)
      return credentials if credentials

      url = authorizer.get_authorization_url(base_url: "http://localhost")
      puts "Open this URL in your browser, approve access, and paste the returned code (or full redirect URL) below:"
      puts url
      print "Authorization code or redirect URL: "

      code = extract_code($stdin.gets&.strip)
      raise "No authorization code received" if code.to_s.empty?

      authorizer.get_and_store_credentials_from_code(
        user_id: USER_ID,
        code: code,
        base_url: "http://localhost"
      )
    end

    private

    attr_reader :client_path, :token_path

    def validate_client_path!
      return if File.exist?(client_path)

      raise "OAuth client file not found at #{client_path}. Create it in Google Cloud Console and set GOOGLE_OAUTH_CLIENT_PATH."
    end

    def authorizer
      @authorizer ||= begin
        client_id = Google::Auth::ClientId.from_file(client_path)
        token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
        Google::Auth::UserAuthorizer.new(client_id, SCOPES, token_store)
      end
    end

    def extract_code(input)
      value = input.to_s.strip
      return value if value.empty?

      uri = URI.parse(value)
      query = URI.decode_www_form(uri.query.to_s).to_h
      query["code"] || value
    rescue URI::InvalidURIError
      value
    end
  end
end
