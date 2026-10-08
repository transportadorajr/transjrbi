Rails.application.routes.draw do
  devise_for :users, skip: :registrations

  devise_scope :user do
    resource :registration, only: %i[edit update], path: 'users', controller: 'devise/registrations', as: :user_registration
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

  root 'home#index'
end
