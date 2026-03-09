# frozen_string_literal: true

module Rules
  class GmailAffectedEmailsLoader
    DEFAULT_QUERY = "in:inbox"
    MAX_MESSAGES_SCANNED = 200
    MAX_DISPLAYED_EMAILS = 25

    def initialize(
      rule:,
      query: DEFAULT_QUERY,
      max_messages_scanned: MAX_MESSAGES_SCANNED,
      max_displayed_emails: MAX_DISPLAYED_EMAILS,
      gmail_client_factory: -> { Gmail::Client.new }
    )
      @rule = rule
      @query = query
      @max_messages_scanned = max_messages_scanned
      @max_displayed_emails = max_displayed_emails
      @gmail_client_factory = gmail_client_factory
    end

    def load
      gmail_client = gmail_client_factory.call
      message_ids = gmail_client.list_message_ids(query: query, max_results: max_messages_scanned)
      dry_run_engine = RuleEngine.new(gmail_client: gmail_client, dry_run: true)

      fetch_error = nil
      matched_count = 0
      emails = []

      message_ids.each do |message_id|
        message = begin
          gmail_client.fetch_normalized_message(message_id)
        rescue StandardError => e
          fetch_error ||= e.message
          next
        end

        result = dry_run_engine.process_message!(message: message, rules_scope: [rule])
        next unless result[:matched] && result[:would_apply]

        matched_count += 1
        next if emails.length >= max_displayed_emails

        emails << build_email_entry(message: message, actions: result[:actions])
      end

      {
        emails: emails,
        total_count: matched_count,
        scanned_count: message_ids.length,
        truncated: matched_count > emails.length,
        error: fetch_error
      }
    rescue StandardError => e
      {
        emails: [],
        total_count: 0,
        scanned_count: 0,
        truncated: false,
        error: e.message
      }
    end

    private

    attr_reader :rule, :query, :max_messages_scanned, :max_displayed_emails, :gmail_client_factory

    def build_email_entry(message:, actions:)
      message = message.with_indifferent_access

      {
        subject: message[:subject].presence || "(subject unavailable)",
        from: message[:from].presence || "(sender unavailable)",
        date: formatted_date(message[:date]),
        gmail_url: gmail_url_for(message[:id], thread_id: message[:thread_id]),
        email_id: message[:id],
        actions: format_actions(actions)
      }
    end

    def formatted_date(date_value)
      parsed = parse_email_date(date_value)
      return parsed.strftime("%Y-%m-%d %H:%M %Z") if parsed

      return date_value.to_s if date_value.present?

      "(date unavailable)"
    end

    def parse_email_date(date_value)
      return nil if date_value.blank?

      Time.zone.parse(date_value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def gmail_url_for(message_id, thread_id:)
      target = thread_id.presence || message_id
      "https://mail.google.com/mail/u/0/#all/#{target}"
    end

    def format_actions(actions)
      Array(actions).map do |action|
        next action[:type] unless action[:label].present?

        "#{action[:type]} (#{action[:label]})"
      end
    end
  end
end
