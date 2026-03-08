# frozen_string_literal: true

module Rules
  class MatchingEmailsLoader
    MAX_DISPLAYED_EMAILS = 50

    def initialize(rule:, gmail_client_factory: -> { Gmail::Client.new })
      @rule = rule
      @gmail_client_factory = gmail_client_factory
    end

    def load
      applications = unique_recent_applications
      return empty_result if applications.empty?

      fetch_error = nil
      gmail_client = nil
      gmail_unavailable = false

      emails = applications.map do |application|
        metadata = message_metadata_from(application)

        if incomplete_metadata?(metadata) && !gmail_unavailable
          begin
            gmail_client ||= gmail_client_factory.call
            gmail_message = gmail_client.fetch_normalized_message(application.gmail_message_id)
            metadata = metadata.merge(metadata_from_gmail_message(gmail_message))
          rescue StandardError => e
            gmail_unavailable = true
            fetch_error ||= e.message
          end
        end

        build_email_entry(application: application, metadata: metadata)
      end

      {
        emails: emails,
        total_count: unique_match_count,
        truncated: unique_match_count > emails.length,
        error: fetch_error
      }
    end

    private

    attr_reader :rule, :gmail_client_factory

    def unique_recent_applications
      seen = {}
      selected = []

      rule.rule_applications.order(applied_at: :desc).each do |application|
        next if seen[application.gmail_message_id]

        seen[application.gmail_message_id] = true
        selected << application
        break if selected.length >= MAX_DISPLAYED_EMAILS
      end

      selected
    end

    def unique_match_count
      @unique_match_count ||= rule.rule_applications.distinct.count(:gmail_message_id)
    end

    def message_metadata_from(application)
      message_payload = application.result.to_h["message"]
      return {} unless message_payload.is_a?(Hash)

      message_payload.with_indifferent_access.slice(:subject, :from, :date, :thread_id)
    end

    def metadata_from_gmail_message(gmail_message)
      {
        subject: gmail_message[:subject],
        from: gmail_message[:from],
        date: gmail_message[:date],
        thread_id: gmail_message[:thread_id]
      }.compact
    end

    def incomplete_metadata?(metadata)
      metadata[:subject].blank? || metadata[:from].blank? || metadata[:date].blank?
    end

    def build_email_entry(application:, metadata:)
      {
        subject: metadata[:subject].presence || "(subject unavailable)",
        from: metadata[:from].presence || "(sender unavailable)",
        date: formatted_date(metadata[:date], fallback: application.applied_at),
        gmail_url: gmail_url_for(application.gmail_message_id, thread_id: metadata[:thread_id])
      }
    end

    def formatted_date(date_value, fallback:)
      parsed = parse_email_date(date_value)
      return parsed.strftime("%Y-%m-%d %H:%M %Z") if parsed

      return date_value if date_value.present?

      fallback.in_time_zone.strftime("%Y-%m-%d %H:%M %Z")
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

    def empty_result
      {
        emails: [],
        total_count: 0,
        truncated: false,
        error: nil
      }
    end
  end
end
