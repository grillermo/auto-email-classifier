# frozen_string_literal: true

class NtfyChannel < ApplicationRecord
  class NotConfiguredError < StandardError; end

  belongs_to :user

  validates :channel, presence: true
  validates :server_url, presence: true

  def notification_url
    "#{server_url}/#{channel}"
  end
end
