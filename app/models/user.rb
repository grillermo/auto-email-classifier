# frozen_string_literal: true

class User < ApplicationRecord
  devise :magic_link_authenticatable, :trackable, :validatable

  has_one :ntfy_channel, dependent: :destroy
  accepts_nested_attributes_for :ntfy_channel

  has_many :gmail_authentications, dependent: :destroy
  has_many :rules, dependent: :destroy
  has_many :rule_applications, dependent: :destroy
  has_many :auto_rule_events, dependent: :destroy
end
