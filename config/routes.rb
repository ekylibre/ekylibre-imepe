# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :backend do
    resources :purchases, only: [] do
      member do
        get :mes_parcelles_extract
      end
    end

    resources :sales, only: [] do
      member do
        get :mes_parcelles_extract
      end
    end
  end
end
