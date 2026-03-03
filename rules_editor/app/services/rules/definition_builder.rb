# frozen_string_literal: true

module Rules
  class DefinitionBuilder
    def initialize(raw_params)
      @raw_params = raw_params
    end

    def build
      {
        match_mode: match_mode,
        conditions: normalized_conditions,
        actions: normalized_actions
      }
    end

    private

    attr_reader :raw_params

    def match_mode
      %w[all any].include?(raw_params[:match_mode]) ? raw_params[:match_mode] : "all"
    end

    def normalized_conditions
      entries_for(:conditions_attributes).filter_map do |condition|
        condition = condition.to_h.with_indifferent_access
        value = condition[:value].to_s.strip
        next if value.empty?

        raw_case_sensitive = condition[:case_sensitive]
        raw_case_sensitive = raw_case_sensitive.last if raw_case_sensitive.is_a?(Array)

        {
          field: condition[:field].to_s,
          operator: condition[:operator].to_s,
          value: value,
          case_sensitive: ActiveModel::Type::Boolean.new.cast(raw_case_sensitive)
        }
      end
    end

    def normalized_actions
      entries_for(:actions_attributes).filter_map do |action|
        action = action.to_h.with_indifferent_access
        type = action[:type].to_s
        next if type.empty?

        payload = { type: type }
        payload[:label] = action[:label].to_s.strip if %w[add_label remove_label].include?(type)
        payload
      end
    end

    def entries_for(key)
      raw_value = raw_params[key]

      case raw_value
      when ActionController::Parameters
        raw_value.values
      when Hash
        raw_value.values
      when Array
        raw_value
      else
        []
      end
    end
  end
end
