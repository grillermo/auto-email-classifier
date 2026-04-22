# frozen_string_literal: true

class CreateNtfyChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :ntfy_channels do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :channel, null: false
      t.string :server_url, null: false, default: "https://ntfy.sh"

      t.timestamps
    end
  end
end
