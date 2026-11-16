# frozen_string_literal: true

require "test_helper"
require_relative "statement_test_helpers"

class Statements::AttachmentExtractorTest < ActiveSupport::TestCase
  include StatementTestHelpers

  def extract(payload, attachments, password: nil)
    service = FakeGmailService.new(attachments)
    Statements::AttachmentExtractor.new(gmail_service: service, message_id: "msg-1", payload: payload, password: password).pdfs
  end

  test "returns plain PDF attachments as they are and skips other attachments" do
    payload = payload_with(
      attachment_part("logo.png", "image/png", "att-png"),
      attachment_part("Estado_de_Cuenta_DiDi_Card.pdf", "application/pdf", "att-pdf")
    )

    pdfs = extract(payload, { "att-png" => "\x89PNG", "att-pdf" => plain_pdf })

    assert_equal [ "Estado_de_Cuenta_DiDi_Card.pdf" ], pdfs.map(&:filename)
    assert_equal plain_pdf, pdfs.first.bytes
  end

  test "decrypts an encrypted PDF with the password" do
    payload = payload_with(attachment_part("EstadodeCuenta.pdf", "application/pdf", "att-pdf"))

    pdfs = extract(payload, { "att-pdf" => encrypted_pdf("secreto") }, password: "secreto")

    assert_equal 1, pdfs.size
    assert pdfs.first.bytes.start_with?("%PDF")
    refute_includes pdfs.first.bytes, "/Encrypt"
  end

  test "raises RetryableError when an encrypted PDF has no password or the wrong one" do
    payload = payload_with(attachment_part("EstadodeCuenta.pdf", "application/pdf", "att-pdf"))
    attachments = { "att-pdf" => encrypted_pdf("secreto") }

    error = assert_raises(Statements::RetryableError) { extract(payload, attachments) }
    assert_match "no password is set", error.message

    error = assert_raises(Statements::RetryableError) { extract(payload, attachments, password: "nope") }
    assert_match "wrong PDF password", error.message
  end

  test "unzips an encrypted ZIP and returns only its PDFs" do
    zip = zip_with({ "EDC2026.pdf" => plain_pdf, "EDC2026.xml" => "<xml/>" }, password: "zip-pw")
    payload = payload_with(attachment_part("EDOS2611.zip", "application/octet-stream", "att-zip"))

    pdfs = extract(payload, { "att-zip" => zip }, password: "zip-pw")

    assert_equal [ "EDC2026.pdf" ], pdfs.map(&:filename)
    assert_equal plain_pdf, pdfs.first.bytes
  end

  test "raises RetryableError for an encrypted ZIP with a wrong or missing password" do
    zip = zip_with({ "EDC2026.pdf" => plain_pdf }, password: "zip-pw")
    payload = payload_with(attachment_part("EDOS2611.zip", "application/octet-stream", "att-zip"))

    assert_raises(Statements::RetryableError) { extract(payload, { "att-zip" => zip }) }
    assert_raises(Statements::RetryableError) { extract(payload, { "att-zip" => zip }, password: "wrong") }
  end

  test "decodes attachment data still in base64url" do
    payload = payload_with(attachment_part("s.pdf", "application/pdf", "att-pdf"))

    pdfs = extract(payload, { "att-pdf" => Base64.urlsafe_encode64(plain_pdf) })

    assert_equal plain_pdf, pdfs.first.bytes
  end

  test "rejects a .pdf attachment that is not a PDF" do
    payload = payload_with(attachment_part("s.pdf", "application/pdf", "att-pdf"))

    assert_raises(Statements::RejectedError) { extract(payload, { "att-pdf" => "%HTML not a pdf" }) }
  end
end
