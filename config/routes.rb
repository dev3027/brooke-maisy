Rails.application.routes.draw do
  # Devise routes with Omniauth callbacks
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # Root route
  root "home#index"

  # Public product catalog routes
  resources :products, only: [ :index, :show ] do
    collection do
      get :search
    end
  end

  resources :categories, only: [ :index, :show ]

  # Cart functionality
  resource :cart, only: [ :show ] do
    member do
      delete :clear
    end
  end

  resources :cart_items, only: [ :create, :update, :destroy ]

  # Order routes
  resources :orders, only: [ :index, :show, :new, :create ] do
    collection do
      get :guest_checkout
    end
  end

  # Admin namespace - authentication handled at controller level
  namespace :admin do
    root "dashboard#index"

    get "dashboard", to: "dashboard#index"
    get "analytics", to: "dashboard#analytics"

    resources :products do
      member do
        patch :toggle_active
        patch :toggle_featured
        post :duplicate
      end

      collection do
        get :bulk_edit
        patch :bulk_update
        delete :bulk_destroy
        get :export
        post :import
      end

      resources :images, only: [ :create, :update, :destroy ] do
        member do
          patch :set_primary
          patch :reorder
        end
      end

      resources :variants, controller: "product_variants"
    end

    resources :categories do
      member do
        patch :toggle_active
        patch :move_up
        patch :move_down
      end

      collection do
        post :reorder
      end
    end

    resources :orders, only: [ :index, :show, :update ] do
      member do
        patch :update_status
        patch :update_payment_status
        post :send_tracking_email
        get :print_invoice
      end
    end

    resources :customers, controller: "users"
    resources :reviews, only: [ :index, :show, :update, :destroy ] do
      member do
        patch :approve
        patch :reject
      end
    end

    resources :articles
    resources :admin_users, only: [ :index, :show, :new, :create, :destroy ]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
