# frozen_string_literal: true

module Rules
  class Matcher
    def initialize(rule:, message:)
      @rule = rule
      @message = message.with_indifferent_access
    end

    def matches?
      outcomes = rule.conditions.map { |condition| condition_match?(condition) }

      if rule.match_mode == "any"
        outcomes.any?
      else
        outcomes.all?
      end
    end

    private

    attr_reader :rule, :message

    def condition_match?(condition)
      expected = condition[:value].to_s
      candidate = field_value(condition[:field]).to_s
      case_sensitive = condition.fetch(:case_sensitive, false)

      left, right = normalize_comparison(candidate, expected, case_sensitive: case_sensitive)

      left.include?(right)
    end

    def field_value(field)
      case field
      when "sender"
        message[:from]
      when "subject"
        message[:subject]
      when "body"
        message[:body]
      else
        ""
      end
    end

    def normalize_comparison(candidate, expected, case_sensitive:)
      return [candidate, expected] if case_sensitive

      [candidate.downcase, expected.downcase]
    end
  end
end
