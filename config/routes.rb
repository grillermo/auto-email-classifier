Rails.application.routes.draw do
  devise_for :users,
    controllers: { omniauth_callbacks: "users/omniauth_callbacks" },
    skip: [:registrations, :passwords, :confirmations, :unlocks, :sessions]

  devise_scope :user do
    get  "sign_in",  to: "users/sessions#new",      as: :new_user_session
    delete "sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
  end

  resources :gmail_authentications, only: [:new]

  # Gmail OAuth — used for adding secondary accounts post sign-in
  scope "/gmail/oauth" do
    get  "authorize", to: "gmail/oauth_callback#new",    as: :gmail_oauth_authorize
    get  "callback",  to: "gmail/oauth_callback#create", as: :gmail_oauth_callback
  end

  get "privacy", to: "pages#privacy", as: :privacy
  get "terms-of-service", to: "pages#terms_of_service", as: :terms_of_service

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/test_google_credentials", to: "health#test_google_credentials"
  get "health/oauth_debug", to: "health#oauth_debug"

  post "rules/apply_all", to: "rules#apply_all"
  resources :rules, only: %i[index new create edit update destroy] do
    collection do
      patch :reorder
    end
  end

  root "rules#index"
end
