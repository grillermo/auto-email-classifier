# frozen_string_literal: true

require "fileutils"
require "google/apis/gmail_v1"
require "googleauth"
require "googleauth/stores/file_token_store"

module Gmail
  class Authorization
    OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
    CREDENTIALS_DIR = File.join(Dir.home, ".credentials")
    DEFAULT_TOKEN_PATH = File.join(CREDENTIALS_DIR, "gmail-modify-token.yaml")
    USER_ID = "default"
    SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_MODIFY
    CREDENTIALS_MISSING_MESSAGE = "No credentials found. Please run ./run.api first to authenticate."

    @authorizer_cache = {}
    @credentials_cache = {}
    @cache_mutex = Mutex.new

    class << self
      attr_reader :cache_mutex

      def default_token_path
        ENV.fetch("GOOGLE_OAUTH_TOKEN_PATH", DEFAULT_TOKEN_PATH)
      end

      def clear_cache!
        cache_mutex.synchronize do
          @authorizer_cache = {}
          @credentials_cache = {}
        end
      end

      def authorizer_cache
        @authorizer_cache
      end

      def credentials_cache
        @credentials_cache
      end
    end

    def initialize(
      token_path: self.class.default_token_path,
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      scope: SCOPE
    )
      @token_path = File.expand_path(token_path)
      @client_id = client_id
      @client_secret = client_secret
      @scope = scope

      validate_environment
      ensure_credentials_directory
    end

    def authorizer
      self.class.cache_mutex.synchronize do
        self.class.authorizer_cache[authorizer_cache_key] ||= build_authorizer
      end
    end

    def fetch_credentials(user_id: USER_ID, use_cache: true)
      cache_key = credentials_cache_key(user_id)
      cached = cached_credentials(cache_key) if use_cache
      return cached if cached

      credentials = authorizer.get_credentials(user_id)
      cache_credentials(cache_key, credentials) if use_cache && credentials
      credentials
    end

    def required_credentials(user_id: USER_ID)
      raise CREDENTIALS_MISSING_MESSAGE unless File.exist?(token_path)

      credentials = fetch_credentials(user_id: user_id)
      raise CREDENTIALS_MISSING_MESSAGE if credentials.nil?

      credentials
    end

    def cache_credentials_for(user_id:, credentials:)
      cache_credentials(credentials_cache_key(user_id), credentials)
    end

    private

    attr_reader :client_id, :client_secret, :scope, :token_path

    def build_authorizer
      google_client = Google::Auth::ClientId.new(client_id, client_secret)
      token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
      Google::Auth::UserAuthorizer.new(google_client, scope, token_store)
    end

    def authorizer_cache_key
      [token_path, client_id, client_secret, scope]
    end

    def credentials_cache_key(user_id)
      [authorizer_cache_key, user_id]
    end

    def cached_credentials(cache_key)
      self.class.cache_mutex.synchronize { self.class.credentials_cache[cache_key] }
    end

    def cache_credentials(cache_key, credentials)
      self.class.cache_mutex.synchronize do
        self.class.credentials_cache[cache_key] = credentials
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
