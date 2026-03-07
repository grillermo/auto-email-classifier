Rails.application.routes.draw do
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
