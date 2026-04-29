Rails.application.routes.draw do
  root "dashboard#show"

  resources :search_queries do
    member do
      post :run
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
