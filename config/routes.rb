H2o::Application.routes.draw do
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  root 'base#index'

  resources :user_sessions, :password_resets, :case_requests, :defects, 
            :case_jurisdictions, :login_notifiers, :bulk_uploads

  get 'base/embedded_pager' => 'base#embedded_pager'
  get 'all_materials' => 'base#search', as: :search_all
  get 'quick_collage' => 'base#quick_collage', as: :quick_collage
  get 'log_out' => 'user_sessions#destroy', as: :log_out
  match 'create_anon' => 'users#create_anon', as: :anonymous_user, via: [:get, :post]
  get 'partial_results/:type' => 'base#partial_results', as: :partial_results
  get '/bookmark_item/:type/:id' => 'users#bookmark_item', as: :bookmark_item
  get '/delete_bookmark_item/:type/:id' => 'users#delete_bookmark_item', as: :delete_bookmark_item
  get '/dropbox_session' => 'dropbox_sessions#create', as: :dropbox_sessions
  get '/:klass/tag/:tag' => 'base#tags', as: :tag

  resources :users do
    member do
      get 'playlists'
      post 'disconnect_canvas'
      post 'disconnect_dropbox'
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
      get 'copy'
    end
    collection do
      get 'embedded_pager'
    end
  end
  resources :playlists do
    member do
      post 'copy'
      post 'deep_copy'
      get 'push'
      get 'access_level'
      get 'export'
      post 'position_update'
      post 'private_notes'
      post 'public_notes'
    end
    collection do
      get 'embedded_pager'
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
    resources :collage_links do
      collection do
        get 'embedded_pager'
      end
    end
    member do
      get 'access_level'
      get 'delete_inherited_annotations'
      post 'export_unique'
      post 'save_readable_state'
      post 'copy'
    end
    collection do
      get 'embedded_pager'
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
      post 'update_permissions'
      get 'manage_users'
      get 'manage_playlists'
      get 'manage_collages'
      get 'manage_permissions'
    end
  end
end
