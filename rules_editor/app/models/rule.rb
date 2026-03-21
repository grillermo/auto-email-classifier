# frozen_string_literal: true

require "digest"

class Rule < ApplicationRecord
  belongs_to :user

  has_many :rule_applications, dependent: :delete_all
  has_many :auto_rule_events, foreign_key: :created_rule_id, dependent: :delete_all, inverse_of: :created_rule

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(priority: :asc, updated_at: :desc) }

  before_validation :ensure_definition_hash

  validates :name, presence: true
  validates :priority, numericality: { only_integer: true, greater_than: 0 }
  validates :definition, uniqueness: { scope: :user_id }
  validate :validate_definition

  def self.next_priority
    maximum(:priority).to_i + 1
  end

  def match_mode
    definition.fetch("match_mode", "all")
  end

  def conditions
    Array(definition["conditions"]).map { |entry| entry.with_indifferent_access }
  end

  def actions
    Array(definition["actions"]).map { |entry| entry.with_indifferent_access }
  end

  def version_digest
    payload = {
      definition: definition,
      updated_at: updated_at&.utc&.iso8601(6)
    }

    Digest::SHA256.hexdigest(payload.to_json)
  end

  private

  def ensure_definition_hash
    self.definition = {} unless definition.is_a?(Hash)
  end

  def validate_definition
    unless %w[all any].include?(match_mode)
      errors.add(:definition, "match_mode must be 'all' or 'any'")
    end

    if conditions.empty?
      errors.add(:definition, "must include at least one condition")
    end

    conditions.each do |condition|
      field = condition[:field]
      operator = condition[:operator]
      value = condition[:value]

      errors.add(:definition, "condition field is invalid") unless %w[sender subject body].include?(field)
      errors.add(:definition, "condition operator is invalid") unless operator == 'contains'
      errors.add(:definition, "condition value cannot be blank") if value.to_s.strip.empty?
    end

    if actions.empty?
      errors.add(:definition, "must include at least one action")
    end

    actions.each do |action|
      type = action[:type]

      unless %w[add_label remove_label mark_read trash].include?(type)
        errors.add(:definition, "action type is invalid")
        next
      end

      if %w[add_label remove_label].include?(type) && action[:label].to_s.strip.empty?
        errors.add(:definition, "label action requires a label")
      end
    end
  end
end
