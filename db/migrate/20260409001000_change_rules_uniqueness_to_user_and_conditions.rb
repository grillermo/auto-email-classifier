# frozen_string_literal: true

class ChangeRulesUniquenessToUserAndConditions < ActiveRecord::Migration[8.1]
  def up
    remove_index :rules, name: "index_rules_on_user_id_and_definition", if_exists: true
    remove_index :rules, name: "index_rules_on_definition_unique", if_exists: true

    execute <<~SQL
      CREATE UNIQUE INDEX index_rules_on_user_id_and_conditions
      ON rules (user_id, ((definition->'conditions')))
    SQL
  end

  def down
    remove_index :rules, name: "index_rules_on_user_id_and_conditions", if_exists: true

    execute <<~SQL
      CREATE UNIQUE INDEX index_rules_on_user_id_and_definition
      ON rules (user_id, (definition::text))
    SQL

    add_index :rules, :definition, unique: true, name: "index_rules_on_definition_unique"
  end
end
