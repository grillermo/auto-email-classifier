# frozen_string_literal: true

require "google/apis/gmail_v1"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

module Gmail
  class OauthManager
    OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
    CREDENTIALS_DIR = File.join(Dir.home, ".credentials")
    DEFAULT_TOKEN_PATH = File.join(CREDENTIALS_DIR, "gmail-modify-token.yaml")
    USER_ID = "default"
    SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_MODIFY

    def initialize(
      token_path: ENV.fetch("GOOGLE_OAUTH_TOKEN_PATH", DEFAULT_TOKEN_PATH),
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"]
    )
      @token_path = token_path
      @client_id = client_id
      @client_secret = client_secret
      validate_environment
      ensure_credentials_directory
    end

    def ensure_credentials!
      credentials = authorizer.get_credentials(USER_ID)
      return credentials if credentials

      perform_authentication(authorizer)
    end

    private

    attr_reader :client_id, :client_secret, :token_path

    def authorizer
      @authorizer ||= begin
        google_client = Google::Auth::ClientId.new(client_id, client_secret)
        token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
        Google::Auth::UserAuthorizer.new(google_client, SCOPE, token_store)
      end
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

      authorizer.get_and_store_credentials_from_code(
        user_id: USER_ID,
        code: code,
        base_url: OOB_URI
      )
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

    def validate_environment
      raise "GOOGLE_CLIENT_ID is not set" if client_id.to_s.strip.empty?
      raise "GOOGLE_CLIENT_SECRET is not set" if client_secret.to_s.strip.empty?
    end

    def ensure_credentials_directory
      FileUtils.mkdir_p(File.dirname(token_path))
    end
  end
end
