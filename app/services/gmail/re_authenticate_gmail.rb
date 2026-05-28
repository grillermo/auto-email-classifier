# frozen_string_literal: true

module Gmail
  class ReAuthenticateGmail
    def initialize(authentications:)
      @authentications = authentications
    end

    def call
      authentications.each { |auth| attempt_reauth(auth) }
    end

    private

    attr_reader :authentications

    def attempt_reauth(auth)
      OauthManager.new(gmail_authentication: auth).ensure_credentials!
      auth.update!(status: :active)
      puts("[ReAuthenticateGmail] account=#{auth.email} reactivated")
    rescue Signet::AuthorizationError => e
      puts("[ReAuthenticateGmail] account=#{auth.email} reauth failed: #{e.class} #{e.message}")
    rescue StandardError => e
      puts("[ReAuthenticateGmail] account=#{auth.email} error: #{e.class} #{e.message}")
    end
  end
end
