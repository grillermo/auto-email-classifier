class CreateRules < ActiveRecord::Migration[8.1]
  def change
    create_table :rules, id: :uuid do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 100
      t.jsonb :definition, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :rules, [:active, :priority]
    add_index :rules, :definition, using: :gin
  end
end
