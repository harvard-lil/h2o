ActionController::Routing::Routes.draw do |map|
  map.resources :metadata

  map.resources :text_blocks, :collection => {:embedded_pager => :get}

  map.resources :item_annotations

  map.resources :item_questions

  map.resources :item_collages

  map.resources :item_cases

  map.resources :item_playlists

  map.resources :item_rotisserie_discussions

  map.resources :item_question_instances

  map.resources :influences

  map.resources :item_texts

  map.resources :item_text_blocks

  map.resources :item_images

  map.resources :item_youtubes

  map.resources :annotations, :collection => {:embedded_pager => :get}

  map.resources :case_jurisdictions

  map.resources :case_docket_numbers

  map.resources :case_citations

  map.resources :cases, :collection => {:embedded_pager => :get}, :member => {:metadata => :get}

  map.resources :collages, :collection => {:embedded_pager => :get}, :member => {:spawn_copy => :post}
  map.collage_tag "collages/tag/:tag", :controller => :collages, :action => :index

  map.resources :playlists, :collection => {:block => :get, :url_check => :post, :load_form => :post, :embedded_pager => :get},
    :member => {:spawn_copy => :post, :position_update => :post, :delete => :get, :copy => [:get, :post], :metadata => :get}
  map.playlist_tag "playlists/tag/:tag", :controller => :playlists, :action => :index

  map.resources :playlist_items, :collection => {:block => :get}, :member => {:delete => :get }

  map.resources :item_defaults

#  map.connect 'casebooks/annotation', :controller => 'casebooks', :action => :annotation, :method => :get
  
  map.resources :rotisserie_trackers

  map.resources :rotisserie_assignments

  map.resources :rotisserie_posts, :collection => {:block => :get}, :member => {:delete => :get }

  map.resources :rotisserie_discussions, :collection => {:block => :get}, :member => {
    :delete => :get, :add_member => :get, :activate => :post, :notify => :post, :changestart => :post, :metadata => :get}

  map.resources :rotisserie_instances, 
    :collection => {:block => :get, :display_validation => [:get, :post], :validate_email_csv => [:post]},
    :member => {:delete => :get, :invite => [:get, :post], :add_member => :get}


  map.resources :questions, :collection => {:embedded_pager => :get} do |q|
    q.vote_for 'vote_for', :controller => 'questions', :action => :vote_for, :method => :get
    q.vote_against 'vote_against', :controller => 'questions', :action => :vote_against, :method => :get
    q.replies 'replies', :controller => 'questions', :action => :replies, :method => :get
  end

  map.resources :question_instances, :member => {:metadata => :get}, :collection => {:embedded_pager => :get}

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  map.resource :account, :controller => "users"
  map.resources :users, :collection => {:create_anon => :post}
  map.resource :user_session, :collection => {:crossroad => [:get,:post]}

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  map.root :controller => "base"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
