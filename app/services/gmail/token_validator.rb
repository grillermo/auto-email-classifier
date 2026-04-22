# frozen_string_literal: true

module Gmail
  class TokenValidator
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      needs_reauth = []

      user.gmail_authentications.status_active.each do |auth|
        Gmail::OauthManager.new(gmail_authentication: auth).ensure_credentials!
      rescue Signet::AuthorizationError
        needs_reauth << auth.email
      end

      { needs_reauth: needs_reauth }
    end

    private

    attr_reader :user
  end
end
