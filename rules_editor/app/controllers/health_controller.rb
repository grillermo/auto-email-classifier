# frozen_string_literal: true

class HealthController < ApplicationController
  def test_google_credentials
    profile = Gmail::Client.new.profile

    render json: {
      ok: true,
      email_address: profile.email_address,
      messages_total: profile.messages_total,
      threads_total: profile.threads_total
    }
  rescue StandardError => e
    render json: {
      ok: false,
      error: e.message
    }, status: :unprocessable_entity
  end
end
