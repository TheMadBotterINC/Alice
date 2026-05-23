Rails.application.routes.draw do
  get "home/index"

  # Datasets
  resources :datasets do
    member do
      get :data
    end
  end
  # Authentication routes
  get "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  # Password reset routes
  resources :password_resets, only: [ :new, :create ], param: :token do
    get :edit, on: :member
    patch :update, on: :member
  end

  # User management (admin only)
  resources :users

  # User settings
  resource :settings, only: [ :show, :update ]

  # Connectors
  resources :connectors do
    member do
      post :test_connection
      get :browse_tables
      get :available_tables
      get :table_schema
    end
    resources :powerbi_workspaces, only: [ :index ]
    resource :powerbi_debug, only: [ :show ], controller: "powerbi_debug"
  end

  # Pipelines
  resources :pipelines do
    member do
      post :run
      post :preview_transformation
      get :save_as_template_form
      post :save_as_template
      get :visual_builder
      patch :update_from_visual_builder
    end
    collection do
      get :templates
      get :new_from_template
      post :create_from_template
      get :new_visual_builder
      post :create_from_visual_builder
    end
    resources :pipeline_runs, only: [ :show ] do
      resource :download, only: [ :show ], controller: "downloads"
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
