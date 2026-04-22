# frozen_string_literal: true

class MakeUserIdNotNull < ActiveRecord::Migration[8.1]
  def up
    # Deduplicate rules with same definition before adding composite unique index
    execute <<~SQL
      DELETE FROM rules
      WHERE id NOT IN (
        SELECT DISTINCT ON (user_id, definition::text) id
        FROM rules
        ORDER BY user_id, definition::text, updated_at DESC
      )
    SQL

    change_column_null :rules,             :user_id, false
    change_column_null :rule_applications, :user_id, false
    change_column_null :auto_rule_events,  :user_id, false

    # Use expression index on definition::text — GIN doesn't support UNIQUE
    execute <<~SQL
      CREATE UNIQUE INDEX index_rules_on_user_id_and_definition
      ON rules (user_id, (definition::text))
    SQL
  end

  def down
    remove_index :rules, name: "index_rules_on_user_id_and_definition", if_exists: true
    change_column_null :rules,             :user_id, true
    change_column_null :rule_applications, :user_id, true
    change_column_null :auto_rule_events,  :user_id, true
  end
end
