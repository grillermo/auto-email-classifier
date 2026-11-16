# frozen_string_literal: true

require "test_helper"
require_relative "statement_test_helpers"

class Statements::ForwarderTest < ActiveSupport::TestCase
  include StatementTestHelpers

  class FakeGmailClient
    attr_reader :service, :modified

    def initialize(service)
      @service = service
      @modified = []
    end

    def ensure_label_id(name) = "Label_#{name}"

    def modify_message(message_id:, add_label_ids: [], remove_label_ids: [])
      @modified << [ message_id, add_label_ids ]
    end
  end

  class FakeIngestClient
    attr_reader :delivered

    def initialize(error: nil)
      @error = error
      @delivered = []
    end

    def deliver(bank_name:, filename:, pdf:)
      raise @error if @error

      @delivered << { bank_name: bank_name, filename: filename, pdf: pdf }
      Statements::IngestClient::Response.new(status: 202, body: { "status" => "queued" })
    end
  end

  setup do
    @user = User.create!(email: "forwarder@example.com")
  end

  def message_with(payload)
    # ScriptRunner hands scripts a Hash with string keys.
    { "id" => "msg-1", "subject" => "Estado de cuenta", "date" => "today", "raw" => Struct.new(:payload).new(payload) }
  end

  def forward(attachments:, payload:, ingest:, password: nil, bank_name: "banamex")
    gmail = FakeGmailClient.new(FakeGmailService.new(attachments))
    forwarder = Statements::Forwarder.new(gmail_client: gmail, message: message_with(payload), bank_name: bank_name, password: password, ingest_client: ingest)
    result = nil
    capture_io { result = forwarder.forward! }
    [ result, gmail ]
  end

  test "decrypts the attached PDF and delivers it under the bank name" do
    ingest = FakeIngestClient.new
    payload = payload_with(attachment_part("EstadodeCuenta.pdf", "application/pdf", "att-1"))

    result, gmail = forward(attachments: { "att-1" => encrypted_pdf("pw") }, payload: payload, ingest: ingest, password: "pw")

    assert_equal [ 202 ], result.map(&:status)
    assert_equal 1, ingest.delivered.size
    assert_equal "banamex", ingest.delivered.first[:bank_name]
    assert_equal "EstadodeCuenta.pdf", ingest.delivered.first[:filename]
    refute_includes ingest.delivered.first[:pdf], "/Encrypt"
    assert_empty gmail.modified
  end

  test "labels the email and re-raises a retryable error so the rule runs again" do
    payload = payload_with(attachment_part("EstadodeCuenta.pdf", "application/pdf", "att-1"))
    gmail = FakeGmailClient.new(FakeGmailService.new({ "att-1" => encrypted_pdf("pw") }))
    forwarder = Statements::Forwarder.new(gmail_client: gmail, message: message_with(payload), bank_name: "banamex", password: nil, ingest_client: FakeIngestClient.new)

    capture_io do
      assert_raises(Statements::RetryableError) { forwarder.forward! }
    end

    assert_equal [ [ "msg-1", [ "Label_statement-ingest-failed" ] ] ], gmail.modified
  end

  test "labels the email and notifies ntfy when the server rejects the file, without raising" do
    @user.create_ntfy_channel!(channel: "test-channel", server_url: "https://ntfy.example")
    payload = payload_with(attachment_part("s.pdf", "application/pdf", "att-1"))
    ingest = FakeIngestClient.new(error: Statements::RejectedError.new("bank-app-parser answered 422"))
    notified = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:post) { |url, body:| notified = [ url, body ] }

    result, gmail = stub_method(HTTP, :headers, ->(*_args, **_kwargs) { fake_http }) do
      forward(attachments: { "att-1" => plain_pdf }, payload: payload, ingest: ingest, bank_name: "didi")
    end

    assert_equal [], result
    assert_equal [ [ "msg-1", [ "Label_statement-ingest-failed" ] ] ], gmail.modified
    assert_equal "https://ntfy.example/test-channel", notified.first
    assert_includes notified.last, "422"
  end

  test "rejects an email without a PDF" do
    payload = payload_with(attachment_part("logo.gif", "image/gif", "att-1"))

    result, gmail = forward(attachments: { "att-1" => "GIF89a" }, payload: payload, ingest: FakeIngestClient.new)

    assert_equal [], result
    assert_equal 1, gmail.modified.size
  end
end
