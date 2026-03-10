# frozen_string_literal: true

module Rules
  class AutoRulesCreator
    DEFAULT_LABEL_TO_CLASSIFY = "classify"

    def initialize(gmail_client: Gmail::Client.new, dry_run: false)
      @gmail_client = gmail_client
      @dry_run = dry_run
    end

    def process!
      log_info("start query=#{classify_query.inspect} max_results=100 dry_run=#{dry_run?}")
      message_ids = gmail_client.list_message_ids(query: classify_query, max_results: 100)
      log_info("fetched candidate_ids=#{message_ids.length}")
      if message_ids.empty?
        log_info("no messages to process")
        return { inspected: 0, created: 0 }
      end

      owner_email = gmail_client.profile.email_address
      log_debug("resolved owner_email=#{owner_email.inspect}")
      created = 0

      message_ids.each do |message_id|
        log_info("processing message_id=#{message_id}")
        if AutoRuleEvent.exists?(source_gmail_message_id: message_id)
          log_info("skipping message_id=#{message_id} reason=already_processed")
          next
        end

        message = gmail_client.fetch_normalized_message(message_id)
        log_debug("fetched message_id=#{message_id} from=#{message[:from].inspect} subject=#{message[:subject].inspect}")
        message_data = extract_rule_data_from_message(message)
        unless message_data
          log_info("skipping message_id=#{message_id} reason=missing_sender_or_subject")
          next
        end

        rule = build_rule_from_message_data(message_data, source_message_id: message_id)
        log_debug("built rule message_id=#{message_id} name=#{rule.name.inspect} priority=#{rule.priority} actions=#{format_actions(rule.actions)}")

        if dry_run?
          log_dry_run("message=#{message_id} would create inactive rule name=#{rule.name.inspect} priority=#{rule.priority} actions=#{format_actions(rule.actions)}")
          log_dry_run("message=#{message_id} would send confirmation email to=#{owner_email.inspect}")
          log_dry_run("message=#{message_id} would mark classify email as read")
          log_info("dry_run finished for message_id=#{message_id}")
          created += 1
          next
        end

        log_debug("saving rule for message_id=#{message_id}")
        rule.save!

        apply_rule(rule, message_id, dry_run: dry_run)
        log_info("saved rule_id=#{rule.id} message_id=#{message_id}")

        notification_gmail_message_id = nil
        begin
          log_debug("sending confirmation email for rule_id=#{rule.id} to=#{owner_email.inspect}")
          notification = send_confirmation_email(rule: rule, to: owner_email)
          notification_gmail_message_id = notification.id
          log_info("sent confirmation email rule_id=#{rule.id} notification_message_id=#{notification_gmail_message_id.inspect}")
        rescue StandardError => e
          puts("Could not send auto-rule confirmation email for rule #{rule.id}: #{e.class} #{e.message}")
        end

        auto_rule_event = AutoRuleEvent.create!(
          source_gmail_message_id: message_id,
          created_rule: rule,
          notification_gmail_message_id: notification_gmail_message_id
        )
        log_debug("created auto_rule_event_id=#{auto_rule_event.id} message_id=#{message_id}")

        created += 1
        log_info("completed message_id=#{message_id} created_count=#{created}")
      rescue StandardError => e
        puts("Classify rule creation failed for message #{message_id}: #{e.class} #{e.message}")
        log_debug("failure backtrace message_id=#{message_id} backtrace=#{Array(e.backtrace).first(5).join(' | ')}")
      end

      log_info("finished inspected=#{message_ids.length} created=#{created}")
      { inspected: message_ids.length, created: created }
    end

    private

    attr_reader :gmail_client

    def dry_run?
      @dry_run
    end

    def classify_label_auto_rule
      ENV.fetch("AUTO_CLASSIFY_LABEL", DEFAULT_LABEL_TO_CLASSIFY)
    end

    def classify_query
      "label:#{classify_label_auto_rule}"
    end

    def remove_inbox_label
      ENV.fetch("AUTO_RULE_DEFAULT_REMOVE_LABEL", "INBOX")
    end

    def apply_rule(rule, message_id, dry_run: true)
      result = Rules::OneOffApplier.new(rule: rule).apply!(message_id: message_id)

      puts "Rule saved and applied (matched: #{result[:matched_count]}, applied: #{result[:applied_count]})"
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
            { type: "remove_label", label: remove_inbox_label },
            { type: "remove_label", label: classify_label_auto_rule },
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

    def log_info(message)
      puts("[auto-rule-debug] #{message}")
    end

    def log_debug(message)
      puts("[auto-rule-debug] #{message}")
    end

    def format_actions(actions)
      Array(actions).map do |action|
        label = action[:label]
        label ? "#{action[:type]}(#{label})" : action[:type]
      end.join(",")
    end
  end
end
