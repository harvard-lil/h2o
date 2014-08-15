class Ability
  include CanCan::Ability

  def initialize(user)
    can [:show, :index], :users
    can :show, :pages
    can [:index, :author_playlists, :search, :not_found, :load_more_users, :tags], :base
    can [:new, :create, :edit, :update], :password_resets
    can [:new, :create], :login_notifiers
    can [:new, :create], :user_sessions
    can :index, [:collages, :playlists, :cases, :text_blocks, :medias, :defaults]

    can [:show, :export], Playlist, :public => true
    can [:show, :export, :export_unique], Collage, :public => true
    can [:show, :export], Case, :public => true
    can [:show, :export], TextBlock, :public => true
    can :show, Media, :public => true

    if user.nil?
      can [:new, :create], :users
      return
    else
      can :playlist_lookup, :playlists
      can :collage_lookup, :collages
      can [:user_lookup, :playlists, :disconnect_canvas, :disconnect_dropbox], :users
      can :create, :defects
      can :quick_collage, :base

      can :destroy, :user_sessions
      can [:bookmark_item, :delete_bookmark_item, :verification_request, :verify], :users
      can :new, [Playlist, Collage, Media, TextBlock, Default, CaseRequest, PlaylistItem]
      can :create, [:playlists, :collages, :medias, :text_blocks, :defaults, :case_requests, :bulk_uploads, :playlist_items, :annotations]
      can [:copy, :deep_copy], Playlist, :public => true
      can :copy, Collage, :public => true
      can :copy, Default, :public => true

      can [:embedded_pager, :access_level], :all

      # Can do things on owned items
      can [:edit, :show, :update, :destroy], [Playlist, Collage, TextBlock, Media, Default, Annotation], :user_id => user.id
      can [:position_update, :public_notes, :private_notes, :toggle_nested_private], Playlist, :user_id => user.id 
      can [:delete_inherited_annotations, :save_readable_state], Collage, :user_id => user.id
      can [:update, :edit, :destroy], PlaylistItem do |playlist_item|
        playlist_item.playlist.user == user
      end

      # Dropbox related permissions
      can :new, BulkUpload
      can :create, :dropbox_sessions
      can :show, BulkUpload, :user_id => user.id

      # User Collection related permissions
      can :new, UserCollection
      can [:edit, :destroy, :update, :manage_users, :manage_playlists, :manage_collages, :manage_permissions, :update_permissions], UserCollection, :user_id => user.id
      can :create, :user_collections
  
      all_permission_assignments = PermissionAssignment.where(user_id: user.id).includes(:permission, :user_collection => [:collages, :playlists])
      permissions_by_id = all_permission_assignments.inject({}) { |h, pa| h[pa.permission.key.to_sym] = pa.user_collection.send("#{pa.permission.permission_type}s").collect { |i| i.id }; h }
      can [:edit, :update, :delete_inherited_annotations, :save_readable_state], Collage, :id => permissions_by_id[:edit_collage] 
      can [:edit, :update, :public_notes, :private_notes, :toggle_nested_private], Playlist, :id => permissions_by_id[:edit_playlist]
      can [:update, :edit, :destroy], PlaylistItem, :playlist_id => permissions_by_id[:edit_playlist]
      can [:show], Collage, :id => permissions_by_id[:view_private_collage]
      can [:show], Playlist, :id => permissions_by_id[:view_private_playlist]
      can [:position_update], Playlist, :id => permissions_by_id[:position_update]
      
      can [:edit, :update], User, :id => user.id
    end

    if user.has_role? :superadmin
      can :access, :rails_admin
      can :dashboard, :all
      can [:index, :export, :bulk_delete, :destroy, :view_in_app, :edit_in_app, :edit, 
           :update, :position_update, :update_notes, :delete_inherited_annotations, :save_readable_state],
        :all
      can :aggregate_items, [Collage, Media, Playlist, TextBlock, Default, User]
      can [:show, :edit, :new], Institution
      cannot [:view_in_app, :edit_in_app], Institution
      can [:import], [Default, Institution]

      can :approve, Case
      can [:new], CaseJurisdiction
      can [:create], :case_jurisdictions
    elsif user.has_role? :case_admin
      can [:new, :edit, :update, :show, :destroy], Case
      can :create, :cases
     
      can :approve, Case
      can [:new], CaseJurisdiction
      can [:create], :case_jurisdictions
      # Add functionality, ability to modify case requests
    elsif user.has_role? :rep
      user_ids = []
      user.institutions.each do |institution|
        user_ids << institution.users.collect { |u| u.id }
      end
      associated_user_ids = user_ids.flatten.uniq
      can :access, :rails_admin
      can :dashboard, :all
      can [:index, :show, :export, :view_in_app], [Playlist, Collage, TextBlock, Media, Default], :user_id => associated_user_ids
    end
  end
end
