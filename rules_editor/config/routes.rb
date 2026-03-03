Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :rules, only: %i[index show edit update] do
    collection do
      patch :reorder
    end
  end

  root "rules#index"
end
