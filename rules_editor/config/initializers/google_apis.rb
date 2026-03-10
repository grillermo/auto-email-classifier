# In an initializer, e.g., config/initializers/google_apis.rb
require 'google/apis/gmail_v1'

Google::Apis.logger = Rails.logger
Google::Apis.logger.level = Logger::ERROR
