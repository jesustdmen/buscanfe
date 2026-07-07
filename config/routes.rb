Rails.application.routes.draw do
  devise_for :users, skip: [:registrations]

  # First-run: criação do primeiro administrador (fecha após existir usuário).
  resource :setup, only: [:new, :create], controller: "setup"

  get "up" => "rails/health#show", as: :rails_health_check

  resource :step_up, only: [:new, :create], controller: "step_up"
  post "environment", to: "environment#update", as: :environment

  resources :certificados, only: [:index, :new, :create, :destroy] do
    collection { post :preview }
  end

  resources :lotes, only: [:new, :create, :show] do
    member do
      post :baixar        # read-only (download loop)
      post :confirmar     # escrita fiscal (exige step-up)
      get  :download_zip  # download em lote (.zip das selecionadas)
      get  :xml           # download individual
    end
  end

  resources :audits, only: [:index]

  root "certificados#index"
end
