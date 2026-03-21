Rails.application.routes.draw do
  # devise-passwordless 0.2 automatically mounts the magic link confirmation route
  # (GET /users/magic_link?token=...) when :magic_link_authenticatable is in the model.
  # This generates the `user_magic_link_url` route helper used by the mailer.
  # Handled by Devise::Passwordless::SessionsController#show internally.
  devise_for :users,
    controllers: { sessions: "users/sessions" },
    skip: [:registrations, :passwords, :confirmations, :unlocks, :omniauth_callbacks]

  devise_scope :user do
    get "users/sign_in", to: "users/sessions#new", as: :new_user_session
    post "users/sign_in", to: "users/sessions#create", as: :user_session
    delete "users/sign_out", to: "users/sessions#destroy", as: :destroy_user_session
  end

  # Gmail OAuth
  scope "/gmail/oauth" do
    get  "authorize", to: "gmail/oauth_callback#new",    as: :gmail_oauth_authorize
    get  "callback",  to: "gmail/oauth_callback#create", as: :gmail_oauth_callback
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/test_google_credentials", to: "health#test_google_credentials"

  post "rules/apply_all", to: "rules#apply_all"
  resources :rules, only: %i[index show edit update] do
    collection do
      patch :reorder
    end
  end

  root "rules#index"
end
