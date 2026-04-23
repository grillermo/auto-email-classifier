class AddLabelsToGmailAuthentications < ActiveRecord::Migration[8.1]
  def change
    add_column :gmail_authentications, :labels, :jsonb, default: []
  end
end
