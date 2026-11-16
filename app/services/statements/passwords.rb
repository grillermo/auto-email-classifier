# frozen_string_literal: true

module Statements
  # Reads statement passwords from config/statement_passwords.rb, a gitignored
  # Ruby file whose last expression is a Hash of bank name => password (see
  # config/statement_passwords.example.rb). The file is read on every lookup,
  # so an edited password is used on the next listener cycle, no restart.
  class Passwords
    PLACEHOLDER = "CHANGE_ME"

    def self.path
      Rails.root.join("config/statement_passwords.rb")
    end

    def self.for(bank_name, path: self.path)
      return nil unless File.file?(path)

      passwords = instance_eval(File.read(path), path.to_s)
      password = passwords.to_h.transform_keys(&:to_s)[bank_name.to_s].to_s
      password.presence unless password == PLACEHOLDER
    end
  end
end
