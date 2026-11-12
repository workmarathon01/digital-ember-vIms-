Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: %i[new create destroy]
  post "session/refresh", to: "sessions#refresh", as: :refresh_session,
                          defaults: { format: :json }

  resources :users do
    member do
      post :lock
      post :unlock
      post :approve_registration
      post :reject_registration
    end
    collection do
      get :pending_registrations
    end
    resource :features, only: %i[show update], controller: "user_features", as: :features
  end

  # Public employee onboarding. Anyone with the link can submit a registration;
  # an administrator or super admin must approve it before the account works.
  namespace :public do
    get "employee_registrations/options", to: "employee_registrations#options", as: :employee_registration_options
    post "employee_registrations", to: "employee_registrations#create", as: :employee_registrations
  end

  get "features/templates", to: "features#templates", as: :feature_templates

  resources :features

  resources :departments, only: %i[index show create update destroy],
                          defaults: { format: :json }

  resources :sites do
    resource :features, only: %i[show update], controller: "site_features", as: :features
  end

  # Site-specific banners. The controller scopes the collection to the
  # signed-in user's working site unless a privileged user selects another site.
  resources :banners

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
      post :send_pass
    end
  end

  # Unauthenticated endpoints for visitor self-registration and QR check-in.
  # Keep this namespace limited to actions that are safe for the public kiosk.
  namespace :public do
    get "visitors/lookup", to: "visitors#lookup", as: :visitor_lookup
    get "visitors/pass", to: "visitors#pass", as: :visitor_pass
    get "visitors/verify", to: "visitors#verify", as: :visitor_verify
    post "visitors/check_in", to: "visitors#check_in", as: :visitor_check_in
    post "visitors/check_out", to: "visitors#check_out", as: :visitor_check_out
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

  # Mobile app API. Authenticated with the same Bearer JWT as the rest of the
  # JSON API. Device registration is scoped to the signed-in user.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :push_tokens, param: :uuid, only: %i[index show create update destroy] do
        collection do
          delete :unregister_all
        end

        member do
          post :test_notification
        end
      end
    end
  end

  root "dashboard#show"
end
