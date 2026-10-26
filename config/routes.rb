Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: %i[new create destroy]
  post "session/refresh", to: "sessions#refresh", as: :refresh_session

  resources :users do
    member do
      post :lock
      post :unlock
    end
    resource :features, only: %i[show update], controller: "user_features", as: :features
  end

  get "features/templates", to: "features#templates", as: :feature_templates

  resources :features

  resources :sites do
    resource :features, only: %i[show update], controller: "site_features", as: :features
  end

  resources :buildings
  resources :floors
  resources :units

  resources :user_sites, only: %i[index create destroy] do
    member do
      post :make_primary
    end
  end

  resources :visitors do
    member do
      post :generate_otp
      post :check_in
      post :check_out
    end
  end

  # Unauthenticated endpoints for visitor self-registration and QR check-in.
  # Keep this namespace limited to actions that are safe for the public kiosk.
  namespace :public do
    get "visitors/lookup", to: "visitors#lookup", as: :visitor_lookup
    get "visitors/verify", to: "visitors#verify", as: :visitor_verify
    post "visitors/check_in", to: "visitors#check_in", as: :visitor_check_in
    post "visitors", to: "visitors#create", as: :visitors
    get "hosts", to: "visitors#hosts", as: :hosts
    get "form_options", to: "visitors#form_options", as: :form_options
  end

  resources :staffs do
    member do
      post :approve
      post :suspend
      post :punch_in
      post :punch_out
    end
  end

  resources :roles
  resources :audit_logs, only: %i[index]

  root "dashboard#show"
end
