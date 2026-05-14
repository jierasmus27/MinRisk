# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "sessions#new"

  get "login", to: "sessions#new", as: :login
  post "session", to: "sessions#create", as: :session
  delete "session", to: "sessions#destroy"

  resources :companies do
    resources :projects do
      resource :upload, only: %i[show create], controller: "project_uploads"
    end
  end
end
