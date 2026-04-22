# Seeds are used for initial setup only.
# The data migration (SeedInitialUser) handles migrating existing records.
# This seed file can be used to create additional test users in development.

if Rails.env.development?
  email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
  ntfy  = ENV.fetch("NTFY_CHANNEL", "test-topic")

  unless User.exists?(email: email)
    User.create!(
      email: email,
      ntfy_channel_attributes: { channel: ntfy, server_url: "https://ntfy.sh" }
    )
    puts "Created dev user: #{email}"
  end
end
