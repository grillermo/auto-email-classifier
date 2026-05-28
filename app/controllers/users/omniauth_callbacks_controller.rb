# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Users::PostSignInRedirect

  def google_oauth2
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_from_google(auth)

    if user.persisted?
      GmailAuthentication.upsert_from_google(user: user, auth: auth)
      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      session["devise.google_data"] = auth.except(:extra)
      redirect_to root_path, alert: "Sign in failed."
    end
  rescue => e
    Rails.logger.error("[OmniauthCallbacks] sign in failed: #{e.class} #{e.message}")
    redirect_to new_user_session_path, alert: "Sign in failed. Please try again."
  end

  def failure
    redirect_to new_user_session_path, alert: "Google sign-in failed: #{failure_message}"
  end
end
