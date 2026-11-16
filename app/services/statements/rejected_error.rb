# frozen_string_literal: true

module Statements
  # The statement can never go through as it is: the server rejected the file
  # (403/422) or the email has no PDF. Retrying would not help.
  class RejectedError < StandardError; end
end
