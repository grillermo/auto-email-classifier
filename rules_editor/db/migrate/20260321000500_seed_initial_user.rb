# frozen_string_literal: true

class SeedInitialUser < ActiveRecord::Migration[8.1]
  def up
    # Skip seeding in test environment — tests create their own users
    return if Rails.env.test?

    admin_email  = ENV.fetch("ADMIN_EMAIL")  { raise "ADMIN_EMAIL env var required for migration" }
    ntfy_channel = ENV.fetch("NTFY_CHANNEL") { raise "NTFY_CHANNEL env var required for migration" }
    ntfy_server  = ENV.fetch("NTFY_SERVER", "https://ntfy.sh")

    # Use parameterized queries to avoid SQL injection
    now = Time.current

    # Create seed user (idempotent)
    execute(
      sanitize_sql_array([
        "INSERT INTO users (id, email, sign_in_count, created_at, updated_at) VALUES (?, ?, 0, ?, ?) ON CONFLICT (email) DO NOTHING",
        SecureRandom.uuid, admin_email, now, now
      ])
    )

    # Fetch actual user id (handles ON CONFLICT DO NOTHING case)
    user_id = execute(
      sanitize_sql_array(["SELECT id FROM users WHERE email = ?", admin_email])
    ).first["id"]

    execute(
      sanitize_sql_array([
        "INSERT INTO ntfy_channels (id, user_id, channel, server_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING",
        SecureRandom.uuid, user_id, ntfy_channel, ntfy_server, now, now
      ])
    )

    # Assign all existing records to seed user (parameterized)
    execute(sanitize_sql_array(["UPDATE rules             SET user_id = ? WHERE user_id IS NULL", user_id]))
    execute(sanitize_sql_array(["UPDATE rule_applications SET user_id = ? WHERE user_id IS NULL", user_id]))
    execute(sanitize_sql_array(["UPDATE auto_rule_events  SET user_id = ? WHERE user_id IS NULL", user_id]))

    # Migrate file-based Gmail token if it exists
    token_path = ENV.fetch("GOOGLE_OAUTH_TOKEN_PATH",
                           File.join(Dir.home, ".credentials", "gmail-modify-token.yaml"))

    if File.exist?(token_path)
      require "yaml"
      token_data   = YAML.safe_load(File.read(token_path), permitted_classes: [Symbol])
      default_data = token_data["default"] || token_data

      execute(
        sanitize_sql_array([
          "INSERT INTO gmail_authentications (id, user_id, email, access_token, refresh_token, token_expires_at, status, scopes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)",
          SecureRandom.uuid, user_id, "migrated@unknown.com",
          default_data["access_token"], default_data["refresh_token"],
          (default_data["expiry_time"] || now + 1.hour),
          "https://www.googleapis.com/auth/gmail.modify",
          now, now
        ])
      )

      say "Migrated Gmail token from #{token_path}"
    else
      say "No Gmail token file found at #{token_path} — skipping. Add a Gmail account via web UI after first login."
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
