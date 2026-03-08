# frozen_string_literal: true

require "base64"
require "google/apis/gmail_v1"

module Gmail
  class Client
    APPLICATION_NAME = "Email Rule Automation"
    DEFAULT_TOKEN_PATH = Gmail::Authorization::DEFAULT_TOKEN_PATH
    AUTHORIZATION_USER_ID = Gmail::Authorization::USER_ID
    MAX_RESULTS_LIMIT = 500

    SYSTEM_LABELS = %w[
      INBOX
      SPAM
      TRASH
      UNREAD
      STARRED
      IMPORTANT
      SENT
      DRAFT
      CATEGORY_PERSONAL
      CATEGORY_SOCIAL
      CATEGORY_PROMOTIONS
      CATEGORY_UPDATES
      CATEGORY_FORUMS
    ].freeze

    def initialize(user_id: "me", token_path: Gmail::Authorization.default_token_path)
      @user_id = user_id
      @authorization = Gmail::Authorization.new(token_path: token_path)
      @service = Google::Apis::GmailV1::GmailService.new
      @service.client_options.application_name = APPLICATION_NAME
      @service.authorization = authorization.required_credentials(user_id: AUTHORIZATION_USER_ID)
      @label_name_to_id = nil
    end

    def profile
      service.get_user_profile(user_id)
    end

    def list_message_ids(query:, max_results: 100)
      messages = []
      page_token = nil

      loop do
        remaining = max_results - messages.size
        page_size = [remaining, MAX_RESULTS_LIMIT].min
        break if page_size <= 0

        response = service.list_user_messages(
          user_id,
          q: query,
          max_results: page_size,
          page_token: page_token
        )

        break if response.messages.nil? || response.messages.empty?

        messages.concat(response.messages)
        break if messages.size >= max_results || response.next_page_token.nil?

        page_token = response.next_page_token
      end

      messages.take(max_results).map(&:id)
    end

    def fetch_message(message_id)
      service.get_user_message(user_id, message_id, format: "full")
    end

    def fetch_normalized_message(message_id)
      message = fetch_message(message_id)
      headers = message.payload&.headers || []

      {
        id: message.id,
        thread_id: message.thread_id,
        date: find_header(headers, "Date"),
        from: find_header(headers, "From"),
        to: find_header(headers, "To"),
        subject: find_header(headers, "Subject"),
        snippet: message.snippet,
        body: extract_best_body(message.payload),
        label_ids: message.label_ids || [],
        raw: message
      }
    end

    def modify_message(message_id:, add_label_ids: [], remove_label_ids: [])
      request = Google::Apis::GmailV1::ModifyMessageRequest.new(
        add_label_ids: add_label_ids,
        remove_label_ids: remove_label_ids
      )
      service.modify_message(user_id, message_id, request)
    end

    def mark_message_read(message_id)
      modify_message(message_id: message_id, remove_label_ids: ["UNREAD"])
    end

    def trash_message(message_id)
      service.trash_user_message(user_id, message_id)
    end

    def ensure_label_id(label_name)
      return label_name if SYSTEM_LABELS.include?(label_name)

      map = label_name_to_id
      return map[label_name] if map.key?(label_name)

      created = service.create_user_label(
        user_id,
        Google::Apis::GmailV1::Label.new(
          name: label_name,
          label_list_visibility: "labelShow",
          message_list_visibility: "show"
        )
      )

      @label_name_to_id = nil
      created.id
    end

    def send_plain_text(to:, subject:, body:, from: "me")
      raw_message = <<~MESSAGE
        From: #{from}
        To: #{to}
        Subject: #{subject}
        MIME-Version: 1.0
        Content-Type: text/plain; charset=UTF-8

        #{body}
      MESSAGE

      encoded = Base64.urlsafe_encode64(raw_message, padding: false)
      message = Google::Apis::GmailV1::Message.new(raw: encoded)
      service.send_user_message(user_id, message)
    end

  private

    attr_reader :authorization, :service, :user_id

    def label_name_to_id
      @label_name_to_id ||= begin
        response = service.list_user_labels(user_id)
        Array(response.labels).index_by(&:name).transform_values(&:id)
      end
    end

    def find_header(headers, name)
      headers.find { |header| header.name.casecmp?(name) }&.value
    end

    def extract_best_body(payload)
      plain_text = extract_body_with_encoding(payload, "text/plain")
      return plain_text unless plain_text.empty?

      html = extract_body_with_encoding(payload, "text/html")
      return strip_html(html) unless html.empty?

      ""
    end

    def extract_body_with_encoding(payload, mime_type)
      return "" if payload.nil?

      if payload.mime_type == mime_type && payload.body&.data
        return decode_body_with_encoding(payload.body.data, payload.headers)
      end

      Array(payload.parts).each do |part|
        if part.mime_type == mime_type && part.body&.data
          return decode_body_with_encoding(part.body.data, part.headers)
        end

        result = extract_body_with_encoding(part, mime_type)
        return result unless result.empty?
      end

      ""
    end

    def decode_body_with_encoding(encoded_data, headers)
      return "" if encoded_data.nil? || encoded_data.empty?

      content_type = find_header(headers || [], "Content-Type")
      charset = extract_charset(content_type) || "UTF-8"

      decoded = begin
        Base64.urlsafe_decode64(encoded_data)
      rescue ArgumentError
        encoded_data.dup
      end

      decoded.encode("UTF-8", charset, invalid: :replace, undef: :replace)
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      decoded.force_encoding("UTF-8")
    end

    def extract_charset(content_type)
      return nil if content_type.nil?

      match = content_type.match(/charset=["']?([^"';\s]+)["']?/i)
      match&.[](1)
    end

    def strip_html(content)
      ActionController::Base.helpers.strip_tags(content)
    end
  end
end
