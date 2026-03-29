Rails.application.routes.draw do
  # devise-passwordless automatically mounts the magic link confirmation route
  # (GET /users/magic_link?user[token]=...) via :magic_link_authenticatable.
  # This generates the `user_magic_link_url` route helper used by the mailer.
  devise_for :users,
    controllers: { sessions: "users/sessions" },
    skip: [:registrations, :passwords, :confirmations, :unlocks, :omniauth_callbacks]

  devise_scope :user do
    get "/users/magic_link",
      to: "devise/passwordless/magic_links#show",
      as: "user_magic_link"
  end

  resources :gmail_authentications, only: [:new]

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
