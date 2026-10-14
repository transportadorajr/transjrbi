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

      root 'imports#index'
    end
  end

  devise_for :users, controllers: { confirmations: 'users/confirmations' }

  devise_scope :user do
    put 'users/confirmation', to: 'users/confirmations#update'
  end

  # Dashboard do GoodJob (somente para usuários autenticados).
  # TODO: restringir por perfil/tipo de usuário quando os perfis forem definidos.
  authenticate :user do
    mount GoodJob::Engine => 'good_job'
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :users, only: %i[index show new create edit update]
  resources :resources, only: %i[index new create edit update destroy]

  root 'home#index'
end
