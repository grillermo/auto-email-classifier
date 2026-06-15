class AddCascadeDeleteToUserForeignKeys < ActiveRecord::Migration[8.1]
  TABLES = %w[auto_rule_events gmail_authentications ntfy_channels rule_applications rules].freeze

  def up
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users, on_delete: :cascade
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, :users
      add_foreign_key table, :users
    end
  end
end
