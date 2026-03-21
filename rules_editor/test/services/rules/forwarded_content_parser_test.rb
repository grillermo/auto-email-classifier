# frozen_string_literal: true

require "test_helper"

class RulesForwardedContentParserTest < ActiveSupport::TestCase
  def parser
    Rules::ForwardedContentParser.new
  end

  test "parses From and Subject from a forwarded email body" do
    body = <<~TEXT
      Begin forwarded message:

      From: Billing Team <billing@example.com>
      Subject: Invoice #1234
      Date: March 2026
    TEXT

    result = parser.parse(body)

    assert_equal "billing@example.com", result[:sender]
    assert_equal "Invoice #1234", result[:subject]
  end

  test "parses De and Asunto (Spanish forwarded format)" do
    body = <<~TEXT
      De: facturacion@empresa.com
      Asunto: Factura Marzo
    TEXT

    result = parser.parse(body)

    assert_equal "facturacion@empresa.com", result[:sender]
    assert_equal "Factura Marzo", result[:subject]
  end

  test "extracts bare email address when no angle brackets" do
    body = "From: plain@example.com\nSubject: Hello"
    result = parser.parse(body)
    assert_equal "plain@example.com", result[:sender]
  end

  test "extracts email from Name <email> format" do
    body = "From: John Doe <john@doe.com>\nSubject: Hi"
    result = parser.parse(body)
    assert_equal "john@doe.com", result[:sender]
  end

  test "returns nil when From line is missing" do
    body = "Subject: Hello\nSome body text"
    assert_nil parser.parse(body)
  end

  test "returns nil when Subject line is missing" do
    body = "From: someone@example.com\nSome body text"
    assert_nil parser.parse(body)
  end

  test "returns nil for blank body" do
    assert_nil parser.parse("")
    assert_nil parser.parse(nil)
  end

  test "uses first From and Subject when multiple appear" do
    body = <<~TEXT
      From: first@example.com
      Subject: First Subject
      From: second@example.com
      Subject: Second Subject
    TEXT
    result = parser.parse(body)
    assert_equal "first@example.com", result[:sender]
    assert_equal "First Subject", result[:subject]
  end
end
