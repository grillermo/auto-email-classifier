# frozen_string_literal: true

class AddUserIdToRulesEtc < ActiveRecord::Migration[8.1]
  def up
    # Drop existing global unique index on rules.definition
    remove_index :rules, name: "index_rules_on_definition", if_exists: true

    add_column :rules,             :user_id, :uuid, null: true
    add_column :rule_applications, :user_id, :uuid, null: true
    add_column :auto_rule_events,  :user_id, :uuid, null: true

    add_foreign_key :rules,             :users, column: :user_id
    add_foreign_key :rule_applications, :users, column: :user_id
    add_foreign_key :auto_rule_events,  :users, column: :user_id

    add_index :rules,             :user_id
    add_index :rule_applications, :user_id
    add_index :auto_rule_events,  :user_id
  end

  def down
    remove_column :rules,             :user_id
    remove_column :rule_applications, :user_id
    remove_column :auto_rule_events,  :user_id
    add_index :rules, :definition, unique: true, using: :gin, name: "index_rules_on_definition"
  end
end
