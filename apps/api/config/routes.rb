Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  namespace :admin do
    get "status", to: "status#show"
    resources :projects, only: [:index, :show, :create, :update, :destroy] do
      resources :api_keys, only: [:index, :create]
    end
    resources :api_keys, only: [:update, :destroy]
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
    end
  end
end
