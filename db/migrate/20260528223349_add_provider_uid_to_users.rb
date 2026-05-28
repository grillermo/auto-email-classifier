class AddProviderUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_index :users, [:provider, :uid],
      unique: true,
      where: "provider IS NOT NULL AND uid IS NOT NULL",
      name: "index_users_on_provider_and_uid"
  end
end
