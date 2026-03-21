namespace :users do
  desc "Create a new user. Required: EMAIL=you@example.com NTFY_CHANNEL=topic. Optional: NTFY_SERVER=https://ntfy.sh"
  task create: :environment do
    email        = ENV.fetch("EMAIL")        { abort "EMAIL is required" }
    ntfy_channel = ENV.fetch("NTFY_CHANNEL") { abort "NTFY_CHANNEL is required" }
    ntfy_server  = ENV.fetch("NTFY_SERVER", "https://ntfy.sh")

    user = User.create!(
      email: email,
      ntfy_channel_attributes: { channel: ntfy_channel, server_url: ntfy_server }
    )
    puts "Created user: #{user.email} (id: #{user.id})"
  end
end
