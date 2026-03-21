# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    protected

    def after_sign_in_path_for(resource)
      Gmail::TokenValidator.call(user: resource)
      super
    end
  end
end
