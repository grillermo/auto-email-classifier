# frozen_string_literal: true

class AutoRuleEvent < ApplicationRecord
  belongs_to :created_rule, class_name: "Rule", inverse_of: :auto_rule_events

  validates :source_gmail_message_id, presence: true, uniqueness: true
end
