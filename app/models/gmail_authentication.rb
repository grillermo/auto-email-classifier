# frozen_string_literal: true

class GmailAuthentication < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  enum :status, { active: "active", needs_reauth: "needs_reauth" }, prefix: true

  validates :email, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true
end
