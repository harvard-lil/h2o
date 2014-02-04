ActionController::Routing::Routes.draw do |map|
  map.resources :defects
  map.resources :metadata

  map.resources :text_blocks, :collection => {:embedded_pager => :get}, :member => {:export => :get}
  map.resources :journal_articles, :member => { :export => :get }
  map.textblock_tag "text_blocks/tag/:tag", :controller => :text_blocks, :action => :index
  map.text_block_tag "text_blocks/tag/:tag", :controller => :text_blocks, :action => :index
  map.journal_article_tag "journal_articles/tag/:tag", :controller => :journal_articles, :action => :index

  map.resources :playlist_items, :collection => {:block => :get}, :member => { :delete => :get }

  map.resources :influences

  map.resources :annotations, :collection => {:embedded_pager => :get}

  map.resources :case_jurisdictions
  map.resources :case_docket_numbers
  map.resources :case_citations

  map.resources :case_requests
  map.resources :cases, :collection => { :embedded_pager => :get, :bulk_upload => [:get, :post], :upload => [:get, :post], :authorize => [:get, :post]}, :member => {:metadata => :get, :export => :get, :approve => :post, :access_level => :get } do |case_obj|
    case_obj.resources :versions
  end

  map.resources :collages, :collection => {:embedded_pager => :get, :collage_lookup => :get },
    :member => { :copy => [:get, :post],
              :save_readable_state => :post,
	            :record_collage_print_state => :post,
              :access_level => :get,
              :export => :get,
              :export_unique => :post,
              :heatmap => :get,
              :upgrade_annotator => :post,
              :delete_inherited_annotations => :get } do |collage|
    collage.resources :versions
  end
  map.collage_tag "collages/tag/:tag", :controller => :collages, :action => :index
  map.resources :collage_links, :collection => {:embedded_pager => :get}

  map.resources :playlists,
    :collection => { :block => :get, :url_check => :post, :load_form => :post, :embedded_pager => :get, :playlist_lookup => :get },
    :member => {:position_update => :post, :toggle_nested_private => :post,
	  :delete => :get, :copy => [:get, :post], :deep_copy => [:get, :post], :push => [:get, :post] ,:metadata => :get,
	  :export => :get, :access_level => :get, :check_export => :get}
  map.playlist_tag "playlists/tag/:tag", :controller => :playlists, :action => :index
  map.notes_tag "playlists/:id/notes/:type", :controller => :playlists, :action => :notes

  map.resources :defaults, :member => { :copy => [:get, :post] },
                           :collection => {:embedded_pager => :get},
                           :as => :links
  map.resources :bulk_uploads
  map.resources :medias, :collection => {:embedded_pager => :get}
  map.media_tag "media/tag/:tag", :controller => :medias, :action => :index

  # Commenting out all Question, Rotisserie routes to disable access
  # map.resources :rotisserie_trackers
  # map.resources :rotisserie_assignments
  # map.resources :rotisserie_posts, :collection => {:block => :get}, :member => {:delete => :get }
  # map.resources :rotisserie_discussions, :collection => {:block => :get}, :member => {
  #  :delete => :get, :add_member => :get, :activate => :post, :notify => :post, :changestart => :post, :metadata => :get}
  # map.resources :rotisserie_instances,
  #  :collection => {:block => :get, :display_validation => [:get, :post], :validate_email_csv => [:post]},
  #  :member => {:delete => :get, :invite => [:get, :post], :add_member => :get}
  # map.resources :questions, :collection => {:embedded_pager => :get} do |q|
  #  q.vote_for 'vote_for', :controller => 'questions', :action => :vote_for, :method => :get
  #  q.vote_against 'vote_against', :controller => 'questions', :action => :vote_against, :method => :get
  #  q.replies 'replies', :controller => 'questions', :action => :replies, :method => :get
  # end
  # map.resources :question_instances, :member => {:metadata => :get}, :collection => {:embedded_pager => :get}

  map.resources :users,
    :collection => { :create_anon => :post, :user_lookup => :get },
    :member => { :playlists => :get }
  map.resources :user_collections, :member => { :update_permissions => :post,
                                                :manage_users => :get,
                                                :manage_playlists => :get,
                                                :manage_collages => :get,
                                                :manage_permissions => :get }
  #FIXME: Why update_permissions route not getting recognized above?
  map.update_permissions "/user_collections/:id/update_permissions", :controller => :user_collections, :action => :update_permissions

  map.resource :user_session, :collection => {:crossroad => [:get,:post]}
  # map.resource :dropbox_session, :collection => {:create => [:get, :post]}
  map.connect '/dropbox_session', :controller => :dropbox_sessions, :action => :create
  map.resources :password_resets
  map.resources :login_notifiers
  map.log_out "/log_out", :controller => :user_sessions, :action => :destroy
  map.anonymous_user "/create_anon", :controller => :users, :action => :create_anon
  map.bookmark_item "/bookmark_item/:type/:id", :controller => :users, :action => :bookmark_item
  map.delete_bookmark_item "/delete_bookmark_item/:type/:id", :controller => :users, :action => :delete_bookmark_item

  map.search_all "/all_materials", :controller => :base, :action => :search
  map.quick_collage "/quick_collage", :controller => :base, :action => :quick_collage
  map.root :controller => "base"
  map.partial_results "/partial_results", :controller => :base, :action => :partial_results
  map.partial_results_show "/partial_results/:dummy/:id", :controller => :base, :action => :partial_results

  map.connect '/p/:id', :controller => :pages, :action => :show

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

  map.connect '*path', :controller => :base, :action => :error
end
