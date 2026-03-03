# frozen_string_literal: true

class RuleApplication < ApplicationRecord
  belongs_to :rule

  validates :gmail_message_id, :rule_version, :applied_at, presence: true

  scope :for_message, ->(gmail_message_id) { where(gmail_message_id: gmail_message_id) }
end
