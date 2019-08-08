H2o::Application.routes.draw do
  mount Ckeditor::Engine => '/ckeditor'
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'
  mount RailsAdminImport::Engine => '/rails_admin_import', :as => 'rails_admin_import'

  root 'base#landing'

  resources :case_courts, only: [:new, :create]
  resources :password_resets, only: [:new, :create, :edit, :update]
  resources :user_sessions, only: [:new, :create, :destroy, :index]

  get 'log_out' => 'user_sessions#destroy', as: :log_out
  get '/p/:id' => 'pages#show'

  resources :users

  scope module: 'content' do
    resources :cases, only: [:show], param: :case_id do
      collection do
        post 'from_capapi', param: :id
      end
    end

    resources :casebooks, param: :casebook_id do
      member do
        post 'clone'
        get 'export'
        get 'layout'
        get 'details'
        get 'revise'
        post 'create_draft'
        patch 'reorder/:child_ordinals', as: :reorder, action: :reorder, child_ordinals: /.*/
        resources :sections, except: [:index], param: :section_ordinals, section_ordinals: /.*/ do
          member do
            get 'details'
            get 'layout'
            get 'clone'
            get 'revise'
            patch 'reorder/:child_ordinals', as: :reorder, action: :reorder, child_ordinals: /.*/
          end
        end
        resources :resources, param: :resource_ordinals, resource_ordinals: /.*/ do
          member do
            get 'details'
            get 'annotate'
            get 'clone'
            get 'create_draft'
          end
        end
      end
    end

    resources :resources, only: [] do
      get 'export'
      resources :annotations
    end

    resources :sections, only: [] do
      get 'export'
    end
  end

  resource :search, only: [:show, :index]
  get '/search', to: 'searches#index'

  get "/pages/*id" => 'pages#show', as: :page, format: false
end
