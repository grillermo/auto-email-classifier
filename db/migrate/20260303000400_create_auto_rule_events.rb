class CreateAutoRuleEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :auto_rule_events, id: :uuid do |t|
      t.string :source_gmail_message_id, null: false
      t.references :created_rule, null: false, foreign_key: { to_table: :rules }, type: :uuid
      t.string :notification_gmail_message_id

      t.timestamps
    end

    add_index :auto_rule_events, :source_gmail_message_id, unique: true
  end
end
