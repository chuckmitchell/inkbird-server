Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "telemetry", to: "telemetry#create"
      post "photos", to: "photos#create"
      post "photo", to: "photos#create"
    end
  end

  resources :photos, only: [ :show ]
  resources :devices, only: [] do
    resources :photos, only: [ :index ]
  end

  root "dashboard#show"
end
