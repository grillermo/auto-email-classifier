# frozen_string_literal: true

require "base64"

module Statements
  # Posts one statement PDF to bank-app-parser's POST /statements/ingest.
  #
  # The endpoint only answers callers on the home LAN (192.168.1.0/24) and
  # refuses 127.0.0.1, so the default URL is the macmini's LAN address even
  # when this app runs on the macmini itself.
  class IngestClient
    DEFAULT_URL = "http://192.168.1.1:4030/statements/ingest"
    DEFAULT_TOKEN_ENV_FILE = File.expand_path("~/c/bank-app-parser/.env")

    Response = Data.define(:status, :body) do
      def success? = [ 200, 202 ].include?(status)
      def already_imported? = status == 200
    end

    def initialize(url: ENV.fetch("STATEMENT_INGEST_URL", DEFAULT_URL), token: nil, http: HTTP)
      @url = url
      @token = token
      @http = http
    end

    # Returns a Response for 200/202. Raises RetryableError when the server or
    # network is down, or when our configuration is wrong (401), and
    # RejectedError when the server refused this file for good (403/422).
    def deliver(bank_name:, filename:, pdf:)
      response = http.timeout(60).auth("Bearer #{token}").post(
        url,
        json: { bank_name: bank_name, filename: filename, pdf: Base64.strict_encode64(pdf) }
      )
      result = Response.new(status: response.code, body: parse(response.body.to_s))

      return result if result.success?
      raise RetryableError, "bank-app-parser answered #{result.status} #{result.body}" if result.status == 401 || result.status >= 500

      raise RejectedError, "bank-app-parser answered #{result.status} #{result.body}"
    rescue HTTP::Error, SystemCallError, IOError => e
      raise RetryableError, "bank-app-parser unreachable at #{url}: #{e.class} #{e.message}"
    end

    private

    attr_reader :url, :http

    # The ingest token lives in bank-app-parser's .env on the same machine, so
    # it is read from there instead of being copied into this app.
    def token
      @token ||= ENV["STATEMENT_INGEST_TOKEN"].presence || token_from_env_file ||
        raise(RetryableError, "no ingest token: set STATEMENT_INGEST_TOKEN or INGEST_TOKEN in #{token_env_file}")
    end

    def token_from_env_file
      return unless File.file?(token_env_file)

      # overwrite: true takes the file's value even if this process happens to
      # have an INGEST_TOKEN of its own.
      Dotenv.parse(token_env_file, overwrite: true)["INGEST_TOKEN"].presence
    end

    def token_env_file
      ENV.fetch("STATEMENT_INGEST_TOKEN_ENV_FILE", DEFAULT_TOKEN_ENV_FILE)
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      body.first(200)
    end
  end
end
