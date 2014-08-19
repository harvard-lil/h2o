H2o::Application.routes.draw do
  mount Ckeditor::Engine => '/ckeditor'
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'
  mount RailsAdminImport::Engine => '/rails_admin_import', :as => 'rails_admin_import'

  root 'base#index'

  resources :bulk_uploads, only: [:show, :new, :create]
  resources :case_jurisdictions, only: [:new, :create]
  resources :case_requests, only: [:new, :create, :destroy]
  resources :defects, only: [:create, :destroy]
  resources :login_notifiers, only: [:new, :create]
  resources :password_resets, only: [:new, :create, :edit, :update]
  resources :user_sessions, only: [:new, :create, :destroy, :index]

  get 'log_out' => 'user_sessions#destroy', as: :log_out
  get '/bookmark_item/:type/:id' => 'users#bookmark_item', as: :bookmark_item
  get '/delete_bookmark_item/:type/:id' => 'users#delete_bookmark_item', as: :delete_bookmark_item
  get '/dropbox_session' => 'dropbox_sessions#create', as: :dropbox_sessions
  get '/p/:id' => 'pages#show'

  resources :base do
    collection do
      get 'embedded_pager'
      get 'load_more_users'
      get 'quick_collage', as: :quick_collage
    end
  end
  get '/:tklass/tag/:tag' => 'base#tags', as: :tag
  get 'author_playlists' => 'base#author_playlists', as: :author_playlists
  get 'all_materials' => 'base#search', as: :search_all

  resources :users do
    member do
      get 'playlists'
      post 'disconnect_canvas'
      post 'disconnect_dropbox'
      get 'verification_request'
      get 'verify/:token' => 'users#verify', as: :verify
    end
    collection do
      get 'user_lookup'
    end
  end
  resources :text_blocks do
    member do
      get 'export'
    end
    collection do
      get 'embedded_pager'
    end
  end
  resources :medias do
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
      post 'deep_copy'
      # get 'push'
      get 'access_level'
      get 'export'
      post 'private_notes'
      post 'public_notes'
      post 'toggle_nested_private'
      post 'position_update'
    end
    collection do
      get 'embedded_pager'
      get 'playlist_lookup'
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
    resources :annotations
    member do
      get 'access_level'
      get 'delete_inherited_annotations'
      post 'export_unique'
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
      get 'embedded_pager'
      post 'approve'
    end
    collection do
      get 'embedded_pager'
    end
  end

  resources :user_collections do
    member do
      patch 'update_permissions'
      get 'manage_users'
      get 'manage_playlists'
      get 'manage_collages'
      get 'manage_permissions'
    end
  end
  
  get '/:id', :to => 'base#not_found'
end
