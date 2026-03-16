Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  get "up" => "rails/health#show", :as => :rails_health_check

  # Public catch endpoint — no auth required
  match "/hook/:token", to: "hooks#catch", via: :all, as: :hook_catch
  match "/hook/:token/*path", to: "hooks#catch", via: :all, as: :hook_catch_path

  namespace :admin do
    get "status", to: "status#show"
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
