class AddUniqueIndexToRulesDefinition < ActiveRecord::Migration[8.1]
  def change
    add_index :rules, :definition, unique: true, name: "index_rules_on_definition_unique"
  end
end
