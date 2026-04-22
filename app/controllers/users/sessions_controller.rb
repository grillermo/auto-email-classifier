# frozen_string_literal: true

module Users
  class SessionsController < Devise::Passwordless::SessionsController
    include PostSignInRedirect
  end
end
