Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"

  namespace :api do
    resources :games, only: %i[show create] do
      member do
        post :join
        post :place_card
        post :discard_to_crib
        post :confirm_round
      end
    end
  end

  get "*path", to: "application#index", constraints: ->(req) {
    !req.path.start_with?("/api", "/cable", "/assets", "/vite-dev", "/up")
  }
  root "application#index"
end
