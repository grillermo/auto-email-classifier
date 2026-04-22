# frozen_string_literal: true

require "set"

class DeduplicateRulesByDefinition < ActiveRecord::Migration[8.1]
  class MigrationRule < ActiveRecord::Base
    self.table_name = "rules"
  end

  class MigrationRuleApplication < ActiveRecord::Base
    self.table_name = "rule_applications"
  end

  class MigrationAutoRuleEvent < ActiveRecord::Base
    self.table_name = "auto_rule_events"
  end

  def up
    duplicate_definitions.each do |definition|
      deduplicate_definition(definition)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Duplicate rules cannot be restored after deduplication"
  end

  private

  def duplicate_definitions
    MigrationRule.group(:definition).having("COUNT(*) > 1").pluck(:definition)
  end

  def deduplicate_definition(definition)
    rules = MigrationRule.where(definition: definition).order(:created_at, :id).to_a
    return if rules.one?

    application_counts = MigrationRuleApplication.where(rule_id: rules.map(&:id)).group(:rule_id).count
    keeper = pick_keeper(rules, application_counts)
    duplicate_rule_ids = rules.map(&:id) - [keeper.id]

    move_rule_applications(duplicate_rule_ids, keeper.id)

    MigrationAutoRuleEvent
      .where(created_rule_id: duplicate_rule_ids)
      .update_all(created_rule_id: keeper.id, updated_at: Time.current)

    MigrationRule.where(id: duplicate_rule_ids).delete_all
  end

  def pick_keeper(rules, application_counts)
    rules.min_by do |rule|
      count = application_counts[rule.id].to_i

      [
        count.positive? ? 0 : 1,
        -count,
        rule.created_at || Time.at(0),
        rule.id
      ]
    end
  end

  def move_rule_applications(duplicate_rule_ids, keeper_rule_id)
    existing_keys = Set.new(
      MigrationRuleApplication
        .where(rule_id: keeper_rule_id)
        .pluck(:gmail_message_id, :rule_version)
    )

    MigrationRuleApplication
      .where(rule_id: duplicate_rule_ids)
      .order(:created_at, :id)
      .each do |application|
      key = [application.gmail_message_id, application.rule_version]

      if existing_keys.include?(key)
        application.delete
        next
      end

      application.update_columns(rule_id: keeper_rule_id, updated_at: Time.current)
      existing_keys << key
    end
  end
end
