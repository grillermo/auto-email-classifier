# frozen_string_literal: true

module Users
  module PostSignInRedirect
    extend ActiveSupport::Concern

    protected

    def after_sign_in_path_for(resource)
      Gmail::TokenValidator.call(user: resource)
      return new_gmail_authentication_path if resource.gmail_authentications.none?

      super
    end
  end
end
