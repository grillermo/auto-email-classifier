# frozen_string_literal: true

module Statements
  # Sends the statement attached to one email to bank-app-parser. Used by the
  # action scripts in action-scripts/send_*_statement.rb.
  #
  # On failure the email gets the FAILED_LABEL so it shows up in Gmail:
  # - RetryableError (server down, wrong token or password) is re-raised, so
  #   the rule is not recorded as applied, its later actions (archive) don't
  #   run, and the next listener cycle tries again.
  # - RejectedError (file refused, no PDF) sends an ntfy notification and lets
  #   the rule finish, since trying again would fail the same way.
  class Forwarder
    FAILED_LABEL = "statement-ingest-failed"

    def initialize(gmail_client:, message:, bank_name:, password: Passwords.for(bank_name), ingest_client: IngestClient.new)
      @gmail_client = gmail_client
      @message = message.to_h.with_indifferent_access
      @bank_name = bank_name
      @password = password
      @ingest_client = ingest_client
    end

    def forward!
      pdfs = extractor.pdfs
      raise RejectedError, "no PDF statement attached" if pdfs.empty?

      pdfs.map do |pdf|
        response = ingest_client.deliver(bank_name: bank_name, filename: pdf.filename, pdf: pdf.bytes)
        log "#{pdf.filename}: #{response.status} #{response.body}"
        response
      end
    rescue RetryableError => e
      fail_with(e, notify: false)
      raise
    rescue RejectedError => e
      fail_with(e, notify: true)
      []
    end

    private

    attr_reader :gmail_client, :message, :bank_name, :password, :ingest_client

    def extractor
      AttachmentExtractor.new(
        gmail_service: gmail_client.send(:service),
        message_id: message[:id],
        payload: message[:raw]&.payload,
        password: password
      )
    end

    def fail_with(error, notify:)
      log "FAILED #{error.class.name.demodulize}: #{error.message}"
      label_failed
      notify(error) if notify
    end

    def label_failed
      gmail_client.modify_message(message_id: message[:id], add_label_ids: [ gmail_client.ensure_label_id(FAILED_LABEL) ])
    rescue StandardError => e
      log "could not add #{FAILED_LABEL} label: #{e.class} #{e.message}"
    end

    def notify(error)
      channel = NtfyChannel.first
      return unless channel

      HTTP.headers("Title" => "#{bank_name} statement not sent to bank-app-parser")
        .post(channel.notification_url, body: "#{message[:subject]} (#{message[:date]})\n#{error.message}")
    rescue StandardError => e
      log "ntfy failed: #{e.class} #{e.message}"
    end

    def log(text)
      puts "[statement:#{bank_name}] message=#{message[:id]} #{text}"
    end
  end
end
