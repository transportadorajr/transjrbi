Rails.application.routes.draw do
  constraints subdomain: Transjrbi::ADMIN_SUBDOMAIN do
    namespace :admin, path: '/' do
      get 'login', to: 'sessions#new', as: :login
      resource :session, only: %i[create destroy]

      resources :imports, only: %i[index new create] do
        get :download, on: :member
        post :reprocess, on: :member
      end
      resources :initial_loads, only: %i[new create]
      resources :http_requests, only: %i[index show]
      resources :tenants, only: %i[index new create edit update] do
        resource :device_registration, only: %i[create update]
      end
      resources :resources, only: %i[index new create edit update destroy]

      constraints ->(request) { Admin::Session.authenticate(request.session[Admin::Authentication::SESSION_TOKEN_KEY]) } do
        mount Flipper::UI.app(Flipper), at: 'flipper', as: :flipper
        mount GoodJob::Engine, at: 'good_job', as: :good_job
      end
      get 'flipper(/*path)', to: redirect('/login', status: 302)
      get 'good_job(/*path)', to: redirect('/login', status: 302)

      root 'imports#index'
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'health#show', as: :rails_health_check

  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker

  constraints subdomain: Transjrbi::APP_SUBDOMAIN do
    devise_for :users, controllers: { confirmations: 'users/confirmations', sessions: 'users/sessions' }

    devise_scope :user do
      put 'users/confirmation', to: 'users/confirmations#update'
    end

    resource :password_change, only: %i[edit update]
    resource :account_password, only: %i[edit update]
    resource :company, only: %i[show edit update]
    resources :users, only: %i[index show new create edit update destroy] do
      member do
        patch :activate
        get :confirmation
        patch :confirm
      end
    end
    resources :transport_documents, only: %i[index show] do
      get :customer_options, on: :collection
      post :resync, on: :member
      resource :distance, only: %i[edit update], controller: 'transport_document_distances'
    end
    resources :manifests, only: %i[index show] do
      get :customer_options, on: :collection
      get :product_options, on: :collection
    end
    resources :customers, only: %i[index show]
    resources :customer_groups do
      patch :regroup, on: :member
    end
    resources :product_groups
    resources :drivers, only: %i[index show edit update destroy]
    resources :vehicles, only: %i[index show]
    resources :expenses, only: %i[index show]
    resources :commission_rules
    resources :macro_regions
    resources :cities
    resources :truck_groups
    resources :excluded_issuers, only: %i[index new create destroy]
    resources :holidays, except: :show
    resources :maintenance_orders, except: :destroy do
      member do
        patch :start
        patch :wait_parts
        patch :cancel
        get :finishing
        patch :finish
      end
      resources :parts, controller: 'maintenance_order_parts', only: %i[new create edit update destroy]
      resources :labors, controller: 'maintenance_order_labors', only: %i[new create edit update destroy]
      resources :services, controller: 'maintenance_order_services', only: %i[new create edit update destroy]
    end
    resources :workshop_employees, except: %i[show destroy]
    resources :suppliers, except: %i[show destroy]
    resources :route_distances, except: :show do
      post :import, on: :collection
    end
    resources :tonnage_rates
    resource :insurance_rate, only: %i[show edit update]
    resource :freight_billing, only: :show do
      get :detail
      get :freights
      get :month
      get :week
      get :product_options
    end
    resource :revenue_projection, only: :show
    resources :trips, only: :index do
      get :detail, on: :collection
      get :product_options, on: :collection
    end
    resources :freight_expenses, only: %i[index] do
      post :recalculate, on: :collection
    end

    root 'home#index'
  end

  constraints subdomain: ['', 'www'] do
    get '(*path)', to: redirect { |_params, request|
      "#{request.protocol}#{Rails.application.config.x.app_host}#{request.port_string}#{request.fullpath}"
    }
  end
end
