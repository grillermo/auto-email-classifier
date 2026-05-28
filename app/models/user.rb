# frozen_string_literal: true

class User < ApplicationRecord
  devise :omniauthable, :trackable,
         omniauth_providers: [:google_oauth2]

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  has_one :ntfy_channel, dependent: :destroy
  accepts_nested_attributes_for :ntfy_channel

  has_many :gmail_authentications, dependent: :destroy
  has_many :rules, dependent: :destroy
  has_many :rule_applications, dependent: :destroy
  has_many :auto_rule_events, dependent: :destroy

  def self.find_or_create_from_google(auth)
    find_by(provider: auth.provider, uid: auth.uid) ||
      find_and_backfill_legacy(auth) ||
      create_from_google(auth)
  end

  private_class_method def self.find_and_backfill_legacy(auth)
    user = find_by(email: auth.info.email)
    return unless user

    user.update!(provider: auth.provider, uid: auth.uid)
    user
  end

  private_class_method def self.create_from_google(auth)
    create!(email: auth.info.email, provider: auth.provider, uid: auth.uid)
  end
end
