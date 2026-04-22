class CreateRuleApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :rule_applications, id: :uuid do |t|
      t.string :gmail_message_id, null: false
      t.references :rule, null: false, foreign_key: true, type: :uuid
      t.string :rule_version, null: false
      t.jsonb :result, null: false, default: {}
      t.datetime :applied_at, null: false

      t.timestamps
    end

    add_index :rule_applications,
              [:gmail_message_id, :rule_id, :rule_version],
              unique: true,
              name: "index_rule_applications_on_message_rule_version"
  end
end
