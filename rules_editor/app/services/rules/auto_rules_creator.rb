# frozen_string_literal: true

module Rules
  class AutoRulesCreator
    DEFAULT_CLASSIFY_QUERY = "label:classify"

    def initialize(gmail_client: Gmail::Client.new, dry_run: false)
      @gmail_client = gmail_client
      @dry_run = dry_run
    end

    def process!
      message_ids = gmail_client.list_message_ids(query: classify_query, max_results: 100)
      return { inspected: 0, created: 0 } if message_ids.empty?

      owner_email = gmail_client.profile.email_address
      created = 0

      message_ids.each do |message_id|
        next if AutoRuleEvent.exists?(source_gmail_message_id: message_id)

        message = gmail_client.fetch_normalized_message(message_id)
        message_data = extract_rule_data_from_message(message)

        rule = build_rule_from_message_data(message_data, source_message_id: message_id)

        if dry_run?
          log_dry_run("message=#{message_id} would create inactive rule name=#{rule.name.inspect} priority=#{rule.priority} actions=#{format_actions(rule.actions)}")
          log_dry_run("message=#{message_id} would send confirmation email to=#{owner_email.inspect}")
          log_dry_run("message=#{message_id} would mark classify email as read")
          created += 1
          next
        end

        rule.save!

        notification_gmail_message_id = nil
        begin
          notification = send_confirmation_email(rule: rule, to: owner_email)
          notification_gmail_message_id = notification.id
        rescue StandardError => e
          Rails.logger.error("Could not send auto-rule confirmation email for rule #{rule.id}: #{e.class} #{e.message}")
        end

        AutoRuleEvent.create!(
          source_gmail_message_id: message_id,
          created_rule: rule,
          notification_gmail_message_id: notification_gmail_message_id
        )

        created += 1
      rescue StandardError => e
        Rails.logger.error("Classify rule creation failed for message #{message_id}: #{e.class} #{e.message}")
      end

      { inspected: message_ids.length, created: created }
    end

    private

    attr_reader :gmail_client

    def dry_run?
      @dry_run
    end

    def classify_query
      ENV["AUTO_RULE_CLASSIFY_QUERY"].presence || ENV.fetch("AUTO_RULE_FORWARD_QUERY", DEFAULT_CLASSIFY_QUERY)
    end

    def remove_inbox_label
      ENV.fetch("AUTO_RULE_DEFAULT_REMOVE_LABEL", "INBOX")
    end

    def build_rule_from_message_data(message_data, source_message_id:)
      sender = message_data.fetch(:sender)
      subject = message_data.fetch(:subject)

      Rule.new(
        name: "Auto: #{sender} | #{subject}".slice(0, 255),
        active: false,
        priority: Rule.next_priority,
        definition: {
          match_mode: "all",
          conditions: [
            { field: "sender", operator: "exact", value: sender, case_sensitive: false },
            { field: "subject", operator: "contains", value: subject, case_sensitive: false }
          ],
          actions: [
            { type: "mark_read" },
            { type: "remove_label", label: remove_inbox_label }
          ]
        },
        metadata: {
          source: "classify_label_auto_rule",
          source_gmail_message_id: source_message_id
        }
      )
    end

    def extract_rule_data_from_message(message)
      sender = normalize_sender(message[:from].to_s)
      subject = message[:subject].to_s.strip
      return nil if sender.empty? || subject.empty?

      {
        sender: sender,
        subject: subject
      }
    end

    def normalize_sender(from_header)
      from_header = from_header.strip
      return "" if from_header.empty?

      matched = from_header.match(/<([^>]+)>/)
      return matched[1].strip if matched

      email = from_header.match(/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i)
      email ? email[0].strip : from_header
    end

    def send_confirmation_email(rule:, to:)
      edit_url = "#{base_url}/rules/#{rule.id}/edit"
      body = <<~BODY
        A new rule was created automatically.

        Name: #{rule.name}
        Priority: #{rule.priority}
        Conditions:
        #{rule.conditions.map { |condition| "- #{condition[:field]} #{condition[:operator]} \"#{condition[:value]}\"" }.join("\n")}
        Actions:
        #{rule.actions.map { |action| action[:label] ? "- #{action[:type]} #{action[:label]}" : "- #{action[:type]}" }.join("\n")}

        Edit rule: #{edit_url}
      BODY

      gmail_client.send_plain_text(
        to: to,
        from: ENV.fetch("AUTO_RULE_REPLY_FROM", "me"),
        subject: "Rule created: #{rule.name}",
        body: body
      )
    end

    def base_url
      ENV.fetch("APP_BASE_URL", "http://localhost:3000")
    end

    def log_dry_run(message)
      puts "[listener] dry-run auto-rule #{message}"
    end

    def format_actions(actions)
      Array(actions).map do |action|
        label = action[:label]
        label ? "#{action[:type]}(#{label})" : action[:type]
      end.join(",")
    end
  end
end
