# frozen_string_literal: true

require "json"

module Users
  class DeviseNotifier < Devise::Mailer
    # Called by devise-passwordless to deliver the magic link.
    # Instead of sending email, we POST the link to the user's ntfy channel.
    def magic_link(record, token, remember_me = false, opts = {})
      @token = token
      @resource = record

      ntfy_channel = record.ntfy_channel
      unless ntfy_channel&.channel.present?
        raise NtfyChannel::NotConfiguredError,
              "User #{record.email} has no ntfy_channel configured"
      end

      magic_link_url = generate_magic_link_url(record, token, remember_me)
      puts "[DeviseNotifier] Sending magic link url #{magic_link_url}"
      deliver_via_ntfy(ntfy_channel, magic_link_url)

      # Return a mail object with deliveries disabled — Devise expects a mail object back
      mail(to: record.email, subject: "Sign in link") do |format|
        format.text { render plain: "Sent via ntfy" }
      end.tap { |m| m.perform_deliveries = false }
    end

    private

    # devise-passwordless expects scoped params such as `user[token]` and
    # `user[email]`, not a top-level `token` query param.
    def generate_magic_link_url(record, token, remember_me)
      resource_name = record.class.model_name.singular_route_key
      opts = (Rails.application.config.action_mailer.default_url_options || {}).merge(
        resource_name.to_sym => {
          email: record.email,
          token: token,
          remember_me: remember_me
        }
      )
      Rails.application.routes.url_helpers.public_send(
        "#{resource_name}_magic_link_url",
        opts
      )
    end

    def deliver_via_ntfy(ntfy_channel, magic_link_url)
      text = <<~BODY
        Sign in to Auto Email Classifier

        Tap or click this link to sign in (valid 15 minutes):
        #{magic_link_url}
      BODY

      body = {
        text: text,
        title: 'Sign in link',
        input: magic_link_url
      }

      HTTP.headers("Content-Type" => "application/json").post(
        ntfy_channel.notification_url,
        body: JSON.generate(body)
      )
    rescue StandardError => e
      Rails.logger.error("[DeviseNotifier] ntfy delivery failed: #{e.class} #{e.message}")
      raise
    end
  end
end
