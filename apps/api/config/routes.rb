Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  get "up" => "rails/health#show", :as => :rails_health_check

  # Setup wizard (first boot)
  get "setup", to: "setup#show"
  post "setup", to: "setup#create"

  # Auth
  namespace :auth do
    post "register", to: "registrations#create"
    get "verify", to: "verifications#show"
    post "resend-verification", to: "verifications#create"
    post "sessions", to: "sessions#create"
    get "me", to: "sessions#show"
    delete "sessions", to: "sessions#destroy"
    post "forgot-password", to: "passwords#create"
    put "reset-password", to: "passwords#update"
    get "github", to: "oauth#github"
    get "github/callback", to: "oauth#github_callback"
    get "invitation", to: "invitations#show"
    post "accept-invitation", to: "invitations#accept"
  end

  # Public catch endpoint — no auth required
  match "/hook/:token", to: "hooks#catch", via: :all, as: :hook_catch
  match "/hook/:token/*path", to: "hooks#catch", via: :all, as: :hook_catch_path

  namespace :admin do
    get "status", to: "status#show"

    # Organization management
    resource :organization, only: [:show, :update]
    resources :members, only: [:index, :destroy]
    resources :invitations, only: [:index, :create, :destroy]

    resources :projects, only: [:index, :show, :create, :update, :destroy] do
      resources :api_keys, only: [:index, :create]
      get "emails", to: "emails#project_index"
      resources :inboxes, only: [:index, :show, :destroy] do
        resources :emails, only: [:index] do
          delete "", on: :collection, action: :purge
        end
      end
      resources :endpoints, param: :token, only: [:index, :show, :create, :update, :destroy] do
        delete :purge, on: :member
        resources :requests, only: [:index, :show, :destroy], module: :endpoints
      end
      resources :requests, only: [:index, :show], controller: "project_requests"
    end
    resources :api_keys, only: [:update, :destroy]

    resources :emails, only: [:show, :destroy] do
      get "raw", on: :member
      resources :attachments, only: [:index]
    end
    resources :attachments, only: [] do
      get "download", on: :member
    end
    get "search", to: "search#show"
  end

  # Site admin
  namespace :site_admin do
    resources :organizations, only: [:index, :show, :update, :destroy] do
      post :grant_permanent, on: :member
    end
    resources :users, only: [:index, :show, :destroy]
    resource :settings, only: [:show]
  end

  namespace :api do
    namespace :v1 do
      get "status", to: "status#show"

      resources :inboxes, only: [:index, :show, :destroy] do
        resources :emails, only: [:index]
        delete "emails", to: "emails#purge", on: :member
      end

      resources :emails, only: [:show, :destroy] do
        get "raw", on: :member
        resources :attachments, only: [:index]
      end

      resources :attachments, only: [] do
        get "download", on: :member
      end

      get "search", to: "search#show"
      post "emails/wait", to: "emails#wait"

      resources :webhooks, only: [:index, :show, :create, :update, :destroy] do
        post "test", on: :member
        resources :deliveries, only: [:index], module: :webhooks
      end

      resources :endpoints, param: :token, only: [:index, :show, :create, :update, :destroy] do
        delete :purge, on: :member
        resources :requests, only: [:index, :show, :destroy], module: :endpoints do
          post :wait, on: :collection
        end
      end
    end
  end
end
