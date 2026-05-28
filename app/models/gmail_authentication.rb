# frozen_string_literal: true

class GmailAuthentication < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  enum :status, { active: "active", needs_reauth: "needs_reauth" }, prefix: true

  validates :email, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true

  def self.upsert_from_google(user:, auth:)
    ga = user.gmail_authentications.find_or_initialize_by(email: auth.info.email)
    creds = auth.credentials

    ga.access_token = creds.token
    ga.refresh_token = creds.refresh_token if creds.refresh_token.present?
    ga.token_expires_at = Time.at(creds.expires_at)
    ga.scopes = Gmail::Authorization::SCOPE
    ga.status = :active
    ga.save!

    fetch_and_store_labels(ga, creds.token)
    ga
  end

  def self.fetch_and_store_labels(ga, access_token)
    google_creds = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      scope: Gmail::Authorization::SCOPE,
      access_token: access_token
    )
    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = google_creds
    response = service.list_user_labels("me")
    labels = Array(response.labels).map { |l| { "id" => l.id, "name" => l.name } }
    ga.update!(labels: labels)
  rescue StandardError => e
    Rails.logger.error("[GmailAuthentication] label fetch failed: #{e.class} #{e.message}")
  end
end
