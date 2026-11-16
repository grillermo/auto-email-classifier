# frozen_string_literal: true

module Statements
  # Something we can fix and retry: the server is down, the token is wrong or a
  # password is missing or wrong. The rule is not marked as applied, so the
  # next listener cycle tries the email again.
  class RetryableError < StandardError; end
end
