# frozen_string_literal: true

require "base64"
require "google/apis/gmail_v1"

module Gmail
  class Client
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

    def initialize(credentials: OauthManager.new.ensure_credentials!, user_id: "me")
      @user_id = user_id
      @service = Google::Apis::GmailV1::GmailService.new
      @service.client_options.application_name = "Email Rule Automation"
      @service.authorization = credentials
      @label_name_to_id = nil
    end

    def profile
      service.get_user_profile(user_id)
    end

    def list_message_ids(query:, max_results: 100)
      response = service.list_user_messages(user_id, q: query, max_results: max_results)
      Array(response.messages).map(&:id)
    end

    def fetch_message(message_id)
      service.get_user_message(user_id, message_id, format: "full")
    end

    def fetch_normalized_message(message_id)
      message = fetch_message(message_id)

      {
        id: message.id,
        thread_id: message.thread_id,
        from: header_value(message, "From"),
        subject: header_value(message, "Subject"),
        body: extract_body(message.payload),
        label_ids: Array(message.label_ids),
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

    attr_reader :service, :user_id

    def label_name_to_id
      @label_name_to_id ||= begin
        response = service.list_user_labels(user_id)
        Array(response.labels).index_by(&:name).transform_values(&:id)
      end
    end

    def header_value(message, name)
      headers = Array(message.payload&.headers)
      found = headers.find { |header| header.name.to_s.casecmp(name).zero? }
      found&.value.to_s
    end

    def extract_body(payload)
      return "" if payload.nil?

      plain_parts = extract_parts(payload, "text/plain")
      html_parts = extract_parts(payload, "text/html")

      return plain_parts.join("\n\n") unless plain_parts.empty?
      return strip_html(html_parts.join("\n\n")) unless html_parts.empty?

      ""
    end

    def extract_parts(part, mime_type)
      parts = []

      if part.mime_type == mime_type && part.body&.data
        parts << decode_body_data(part.body.data)
      end

      Array(part.parts).each do |child|
        parts.concat(extract_parts(child, mime_type))
      end

      parts
    end

    def decode_body_data(data)
      return "" if data.nil?

      Base64.urlsafe_decode64(data + ("=" * ((4 - data.length % 4) % 4)))
    rescue ArgumentError
      ""
    end

    def strip_html(content)
      ActionController::Base.helpers.strip_tags(content)
    end
  end
end
