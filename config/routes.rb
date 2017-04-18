H2o::Application.routes.draw do
  get 'svg_icons/:icon_set/:size', to: 'svg_icons#show'

  mount Ckeditor::Engine => '/ckeditor'
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'
  mount RailsAdminImport::Engine => '/rails_admin_import', :as => 'rails_admin_import'

  root 'base#index'

  resources :bulk_uploads, only: [:show, :new, :create]
  resources :case_jurisdictions, only: [:new, :create]
  resources :case_requests, only: [:new, :create, :destroy]
  resources :password_resets, only: [:new, :create, :edit, :update]
  resources :user_sessions, only: [:new, :create, :destroy, :index]
  resource :case_finder, only: [:new, :create, :show] do
    get 'download'
  end

  get 'log_out' => 'user_sessions#destroy', as: :log_out
  get '/bookmark_item/:type/:id' => 'users#bookmark_item', as: :bookmark_item
  get '/delete_bookmark_item/:type/:id' => 'users#delete_bookmark_item', as: :delete_bookmark_item
  get '/dropbox_session' => 'dropbox_sessions#create', as: :dropbox_sessions
  get '/p/:id' => 'pages#show'

  resources :base, only: [] do
    collection do
      get 'embedded_pager'
    end
  end
  get 'all_materials' => 'base#search', as: :search_all

  resources :users do
    member do
      get 'playlists'
      # post 'disconnect_dropbox'
      # get 'verification_request'
      # get 'verify/:token' => 'users#verify', as: :verify
    end
    collection do
      get 'user_lookup'
    end
  end
  resources :text_blocks do
    resources :responses, :only => [:create, :destroy]
    resources :annotations
    member do
      get 'export'
      post 'export_as'
    end
    collection do
      get 'embedded_pager'
    end
  end
  resources :defaults do
    member do
      post 'copy'
    end
    collection do
      get 'embedded_pager'
    end
  end

  resources :playlists do
    member do
      post 'copy'
      get 'access_level'
      get 'export'
      get 'export_all' => 'playlists#export', load_all: '1'
      post 'export_as'
      post 'private_notes'
      post 'public_notes'
      post 'toggle_nested_private'
      post 'position_update'
    end
    collection do
      get 'embedded_pager'
      get 'playlist_lookup'
      get 'import'
      post 'submit_import'
      get 'empty'
    end
  end
  resources :playlist_items do
    member do
      get 'delete'
    end
    collection do
      get 'block'
    end
  end
  resources :collages do
    resources :responses, :only => [:create, :destroy]
    resources :annotations
    member do
      get 'access_level'
      get 'delete_inherited_annotations'
      get 'export_unique'
      post 'export_unique'
      get 'export'
      post 'export_as'
      post 'save_readable_state'
      post 'copy'
      get 'collage_list'
    end
    collection do
      get 'embedded_pager'
      get 'collage_lookup'
    end
  end
  resources :cases do
    member do
      get 'access_level'
      get 'export'
      post 'export_as'
      get 'embedded_pager'
      post 'approve'
    end
    collection do
      get 'embedded_pager'
    end
  end

  scope :iframe, controller: 'iframe' do
    get 'load/:type/:id(.:format)', action: :load, as: 'iframe_load'
    get 'show/:type/:id(.:format)', action: :show, as: 'iframe_show'
  end

  get '/:controller/:id/copy', :to => 'base#not_found'
  get '/:id', :to => 'base#not_found'
end
