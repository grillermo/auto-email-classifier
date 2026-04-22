# frozen_string_literal: true

class CreateGmailAuthentications < ActiveRecord::Migration[8.1]
  def change
    create_table :gmail_authentications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :email,               null: false
      t.text    :access_token
      t.text    :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_refreshed_at
      t.string  :status,              null: false, default: "active"
      t.string  :scopes

      t.timestamps
    end

    add_index :gmail_authentications, [ :user_id, :email ], unique: true
  end
end
