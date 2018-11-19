H2o::Application.routes.draw do
  get 'svg_icons/:icon_set/:size', to: 'svg_icons#show'

  mount Ckeditor::Engine => '/ckeditor'
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'
  mount RailsAdminImport::Engine => '/rails_admin_import', :as => 'rails_admin_import'

  root 'base#landing'

  resources :bulk_uploads, only: [:show, :new, :create]
  resources :case_courts, only: [:new, :create]
  resources :password_resets, only: [:new, :create, :edit, :update]
  resources :user_sessions, only: [:new, :create, :destroy, :index]

  get 'log_out' => 'user_sessions#destroy', as: :log_out
  get '/dropbox_session' => 'dropbox_sessions#create', as: :dropbox_sessions
  get '/p/:id' => 'pages#show'

  get 'all_materials' => 'base#search', as: :search_all

  resources :users do
    member do
      # post 'disconnect_dropbox'
      # get 'verification_request'
      get 'verify/:token' => 'users#verify', as: :verify
    end
    collection do
      get 'user_lookup'
    end
  end
  resources :text_blocks do
    resources :responses, :only => [:create, :destroy]
    member do
      get 'export'
      post 'export_as'
    end
  end
  resources :defaults do
    member do
      post 'copy'
    end
  end


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
            get 'build_draft'
          end
        end
      end
    end

    resources :resources, only: [] do
      get 'export'
      resources :annotations, only: [:create, :destroy, :update]
    end

    resources :sections, only: [] do
      get 'export'
    end
  end

  resource :search, only: [:show, :index]
  get '/search', to: 'searches#index'

  scope :iframe, controller: 'iframe' do
    get 'load/:type/:id(.:format)', action: :load, as: 'iframe_load'
    get 'show/:type/:id(.:format)', action: :show, as: 'iframe_show'
  end

  get "/pages/*id" => 'pages#show', as: :page, format: false

  get '*path', to: 'base#not_found'
end
