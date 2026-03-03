# frozen_string_literal: true

module Rules
  class ActionExecutor
    def initialize(rule:, message:, gmail_client:)
      @rule = rule
      @message = message.with_indifferent_access
      @gmail_client = gmail_client
    end

    def execute!
      applied_actions = []

      rule.actions.each do |action|
        type = action[:type]

        case type
        when "add_label"
          label_name = action[:label].to_s
          label_id = gmail_client.ensure_label_id(label_name)
          gmail_client.modify_message(message_id: message[:id], add_label_ids: [label_id])
          applied_actions << { type: type, label: label_name }
        when "remove_label"
          label_name = action[:label].to_s
          label_id = gmail_client.ensure_label_id(label_name)
          gmail_client.modify_message(message_id: message[:id], remove_label_ids: [label_id])
          applied_actions << { type: type, label: label_name }
        when "mark_read"
          gmail_client.mark_message_read(message[:id])
          applied_actions << { type: type }
        when "trash"
          gmail_client.trash_message(message[:id])
          applied_actions << { type: type }
        end
      end

      applied_actions
    end

    private

    attr_reader :rule, :message, :gmail_client
  end
end
