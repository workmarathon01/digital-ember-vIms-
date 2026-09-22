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
  end

  resources :visitors do
    member do
      post :generate_otp
      post :check_in
      post :check_out
    end
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
