# frozen_string_literal: true

module MailListener
  class ProcessCycleJob < ApplicationJob
    queue_as :default

    def perform
      needs_reauth = GmailAuthentication.status_needs_reauth.includes(user: :ntfy_channel)
      if needs_reauth.any?
        Gmail::ReAuthenticateGmail.new(authentications: needs_reauth).call
      end

      auths = GmailAuthentication.status_active.includes(user: :ntfy_channel)

      if auths.empty?
        puts("[ProcessCycleJob] no active gmail_authentications, skipping") if needs_reauth.empty?
        return

      puts("[ProcessCycleJob] processing #{auths.count} active account(s)")

      auths.each do |auth|
        begin
          CycleProcessor.new(gmail_authentication: auth).process!
        rescue StandardError => e
          puts("[ProcessCycleJob] account=#{auth.email} error=#{e.class} #{e.message}")
        end
      end
    end
  end
end
