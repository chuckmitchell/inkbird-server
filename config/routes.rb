Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "telemetry", to: "telemetry#create"
    end
  end

  root "dashboard#show"
end
