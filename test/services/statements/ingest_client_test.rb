# frozen_string_literal: true

require "test_helper"

class Statements::IngestClientTest < ActiveSupport::TestCase
  # Stands in for the http gem's chain: HTTP.timeout(..).auth(..).post(..).
  class FakeHttp
    FakeResponse = Struct.new(:code, :body)
    attr_reader :posted, :auth_header

    def initialize(code: 202, body: '{"status":"queued"}', error: nil)
      @code = code
      @body = body
      @error = error
    end

    def timeout(_seconds) = self

    def auth(header)
      @auth_header = header
      self
    end

    def post(url, json:)
      raise @error if @error

      @posted = { url: url, json: json }
      FakeResponse.new(@code, @body)
    end
  end

  def client(http, token: "tok")
    Statements::IngestClient.new(url: "http://192.168.1.1:4030/statements/ingest", token: token, http: http)
  end

  def deliver(http)
    client(http).deliver(bank_name: "didi", filename: "s.pdf", pdf: "%PDF")
  end

  test "posts the bank, filename and base64 PDF with the bearer token" do
    http = FakeHttp.new

    response = client(http).deliver(bank_name: "didi", filename: "s.pdf", pdf: "%PDF-1.7 bytes")

    assert response.success?
    assert_equal 202, response.status
    assert_equal({ "status" => "queued" }, response.body)
    assert_equal "Bearer tok", http.auth_header
    assert_equal "didi", http.posted[:json][:bank_name]
    assert_equal "s.pdf", http.posted[:json][:filename]
    assert_equal "%PDF-1.7 bytes", Base64.strict_decode64(http.posted[:json][:pdf])
  end

  test "treats 200 already imported as success" do
    response = deliver(FakeHttp.new(code: 200, body: '{"status":"already imported"}'))

    assert response.success?
    assert response.already_imported?
  end

  test "raises RetryableError for 5xx, 401 and network errors" do
    assert_raises(Statements::RetryableError) { deliver(FakeHttp.new(code: 503, body: "down")) }
    assert_raises(Statements::RetryableError) { deliver(FakeHttp.new(code: 401, body: '{"error":"unauthorized"}')) }
    assert_raises(Statements::RetryableError) { deliver(FakeHttp.new(error: HTTP::ConnectionError.new("refused"))) }
  end

  test "raises RejectedError for 422 and 403" do
    error = assert_raises(Statements::RejectedError) { deliver(FakeHttp.new(code: 422, body: '{"error":"pdf is not a PDF file"}')) }
    assert_match "pdf is not a PDF file", error.message

    assert_raises(Statements::RejectedError) { deliver(FakeHttp.new(code: 403, body: '{"error":"forbidden"}')) }
  end

  test "reads INGEST_TOKEN from bank-app-parser's env file" do
    Dir.mktmpdir do |dir|
      env_file = File.join(dir, "bank-app.env")
      File.write(env_file, "OTHER=1\nINGEST_TOKEN=from-file\n")
      http = FakeHttp.new

      with_env("STATEMENT_INGEST_TOKEN" => nil, "STATEMENT_INGEST_TOKEN_ENV_FILE" => env_file) do
        Statements::IngestClient.new(http: http).deliver(bank_name: "didi", filename: "s.pdf", pdf: "%PDF")
      end

      assert_equal "Bearer from-file", http.auth_header
    end
  end

  test "raises RetryableError when no token is configured" do
    with_env("STATEMENT_INGEST_TOKEN" => nil, "STATEMENT_INGEST_TOKEN_ENV_FILE" => "/nonexistent/bank-app.env") do
      assert_raises(Statements::RetryableError) do
        Statements::IngestClient.new(http: FakeHttp.new).deliver(bank_name: "didi", filename: "s.pdf", pdf: "%PDF")
      end
    end
  end

  private

  def with_env(values)
    saved = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
