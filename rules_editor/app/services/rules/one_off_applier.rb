# frozen_string_literal: true

module Rules
  class OneOffApplier
    DEFAULT_QUERY = "in:inbox"

    def initialize(rule:, gmail_client: Gmail::Client.new)
      @rule = rule
      @gmail_client = gmail_client
    end

    def apply!(query: DEFAULT_QUERY)
      engine = RuleEngine.new(gmail_client: gmail_client)

      matched_count = 0
      applied_count = 0

      gmail_client.list_message_ids(query: query, max_results: 500).each do |message_id|
        message = gmail_client.fetch_normalized_message(message_id)
        result = engine.process_message!(message: message, rules_scope: [rule])
        next unless result[:matched]

        matched_count += 1
        applied_count += 1 if result[:applied]
      end

      { matched_count: matched_count, applied_count: applied_count }
    end

    private

    attr_reader :rule, :gmail_client
  end
end
