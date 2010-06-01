ActionController::Routing::Routes.draw do |map|
  map.resources :item_texts

  map.resources :item_images

  map.resources :item_youtubes

  map.resources :excerpts

  map.resources :annotations

  map.resources :case_jurisdictions

  map.resources :case_docket_numbers

  map.resources :case_citations

  map.resources :cases

  map.resources :collages do |cl|
    cl.undo_annotation 'undo_annotation', :controller => 'collages', :action => :undo_annotation, :method => :post
    cl.undo_excerpt 'undo_excerpt', :controller => 'collages', :action => :undo_excerpt, :method => :post
  end

  map.resources :playlists, :collection => {:block => :get, :url_check => :post, :load_form => :post}, :member => {:position_update => :post, :delete => :get }

  map.resources :playlist_items, :collection => {:block => :get}, :member => {:delete => :get }

  map.resources :item_defaults

#  map.connect 'casebooks/annotation', :controller => 'casebooks', :action => :annotation, :method => :get
  
  map.resources :rotisserie_trackers

  map.resources :rotisserie_assignments

  map.resources :rotisserie_posts, :collection => {:block => :get}, :member => {:delete => :get }

  map.resources :rotisserie_discussions, :collection => {:block => :get}, :member => {
    :delete => :get, :add_member => :get, :activate => :post, :notify => :post, :changestart => :post}

  map.resources :rotisserie_instances, :collection => {:block => :get}, :member => {:delete => :get }

  map.resources :questions do |q|
    q.vote_for 'vote_for', :controller => 'questions', :action => :vote_for, :method => :get
    q.vote_against 'vote_against', :controller => 'questions', :action => :vote_against, :method => :get
    q.replies 'replies', :controller => 'questions', :action => :replies, :method => :get
  end

  map.resources :question_instances

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
