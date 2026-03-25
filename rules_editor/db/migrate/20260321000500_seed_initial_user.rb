# frozen_string_literal: true

class SeedInitialUser < ActiveRecord::Migration[8.1]
  def up
# Skip seeding in test environment — tests create their own users
    return if Rails.env.test?

    admin_email  = ENV.fetch("ADMIN_EMAIL")  { raise "ADMIN_EMAIL env var required for migration" }
    ntfy_channel = ENV.fetch("NTFY_CHANNEL") { raise "NTFY_CHANNEL env var required for migration" }
    ntfy_server  = ENV.fetch("NTFY_SERVER", "https://ntfy.sh")

    # Use connection.quote to safely escape values and avoid SQL injection
    now = Time.current

    # Create seed user (idempotent)
    execute(<<~SQL)
      INSERT INTO users (id, email, sign_in_count, created_at, updated_at)
      VALUES (#{quote(SecureRandom.uuid)}, #{quote(admin_email)}, 0, #{quote(now)}, #{quote(now)})
      ON CONFLICT (email) DO NOTHING
    SQL

    # Fetch actual user id (handles ON CONFLICT DO NOTHING case)
    user_id = execute(<<~SQL).first["id"]
      SELECT id FROM users WHERE email = #{quote(admin_email)}
    SQL

    execute(<<~SQL)
      INSERT INTO ntfy_channels (user_id, channel, server_url, created_at, updated_at)
      VALUES (#{quote(user_id)}, #{quote(ntfy_channel)}, #{quote(ntfy_server)}, #{quote(now)}, #{quote(now)})
      ON CONFLICT DO NOTHING
    SQL

    # Assign all existing records to seed user
    execute("UPDATE rules             SET user_id = #{quote(user_id)} WHERE user_id IS NULL")
    execute("UPDATE rule_applications SET user_id = #{quote(user_id)} WHERE user_id IS NULL")
    execute("UPDATE auto_rule_events  SET user_id = #{quote(user_id)} WHERE user_id IS NULL")

    # Migrate file-based Gmail token if it exists
    token_path = ENV.fetch("GOOGLE_OAUTH_TOKEN_PATH",
                           File.join(Dir.home, ".credentials", "gmail-modify-token.yaml"))

    if File.exist?(token_path)
      require "yaml"
      token_data   = YAML.safe_load(File.read(token_path), permitted_classes: [Symbol])
      default_data = token_data["default"] || token_data

      execute(<<~SQL)
        INSERT INTO gmail_authentications (id, user_id, email, access_token, refresh_token, token_expires_at, status, scopes, created_at, updated_at)
        VALUES (
          #{quote(SecureRandom.uuid)},
          #{quote(user_id)},
          'migrated@unknown.com',
          #{quote(default_data["access_token"])},
          #{quote(default_data["refresh_token"])},
          #{quote(default_data["expiry_time"] || now + 1.hour)},
          'active',
          'https://www.googleapis.com/auth/gmail.modify',
          #{quote(now)},
          #{quote(now)}
        )
      SQL

      say "Migrated Gmail token from #{token_path}"
    else
      say "No Gmail token file found at #{token_path} — skipping. Add a Gmail account via web UI after first login."
    end  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
