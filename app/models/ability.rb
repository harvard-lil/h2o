class Ability
  include CanCan::Ability

  def initialize(user)
    can [:show, :index], :users
    can :show, :pages
    can [:landing, :index, :author_playlists, :search, :not_found, :load_more_users, :tags], :base
    can [:new, :create, :edit, :update], :password_resets
    can [:new, :create], :login_notifiers
    can [:new, :create], :user_sessions
    can :index, [:collages, :playlists, :cases, :text_blocks, :defaults]

    can [:show, :export, :export_as], Content::Node, :public => true
    can [:show, :export, :export_as, :export_unique], Collage, :public => true
    can [:show, :export, :export_as], Case, :public => true
    can [:show, :export, :export_as], TextBlock, :public => true
    can :show, PlaylistItem

    if user.nil?
      can [:new, :create], :users
      return
    else
      can [:playlist_lookup], :playlists
      can :collage_lookup, :collages
      can [:user_lookup, :playlists, :disconnect_dropbox], :users
      can :create, :responses

      can :destroy, :user_sessions
      can [:bookmark_item, :delete_bookmark_item, :verification_request, :verify], :users
      can :new, [Content::Casebook, Collage, TextBlock, Default, CaseRequest]
      can :create, [:casebooks, :collages, :text_blocks, :defaults, :case_requests, :bulk_uploads, :playlist_items, :annotations]
      can :copy, Playlist, :public => true
      can :copy, Collage, :public => true
      can :copy, Default, :public => true
      can :copy, Playlist, :user_id => user.id
      can :copy, Collage, :user_id => user.id
      can :copy, Default, :user_id => user.id

      can [:embedded_pager, :access_level], :all

      # Can do things on owned items
      if !user.has_role? :superadmin
        can [:edit, :show, :update, :destroy, :export, :export_as, :export_unique], [Playlist, Collage, TextBlock, Default], :user_id => user.id
      end
      can [:position_update, :public_notes, :private_notes, :toggle_nested_private], Playlist, :user_id => user.id
      can [:delete_inherited_annotations, :save_readable_state], Collage, :user_id => user.id
      can [:update, :edit, :destroy], PlaylistItem do |playlist_item|
        playlist_item.playlist.user == user
      end
      can [:update, :destroy], Annotation do |annotation|
        annotation.annotated_item.user == user || annotation.user == user
      end
      can :destroy, Response do |response|
        response.resource.user == user
      end

      # Dropbox related permissions
      can :new, BulkUpload
      can :create, :dropbox_sessions
      can :show, BulkUpload, :user_id => user.id

      # superadmins can edit/update any id, not just their own
      if !user.has_role? :superadmin
        can [:edit, :update], User, :id => user.id
      end
    end

    if user.has_role? :superadmin
      can [:edit, :update], User

      can :access, :rails_admin
      can [:create], :"ckeditor/pictures"
      can [:create], :"ckeditor/assets"
      can [:create], :"ckeditor/attachment_files"
      can :dashboard, :all
      can [:import, :submit_import, :empty], :playlists
      can [:index, :show, :export, :export_as, :export_unique, :bulk_delete, :destroy, :view_in_app, :edit_in_app, :edit,
           :update, :position_update, :update_notes, :delete_inherited_annotations, :save_readable_state],
        :all
      can :aggregate_items, [Collage, Playlist, TextBlock, Default, User]
      can :delete_playlist_nested, Playlist
      can [:show, :edit, :new], Institution
      cannot [:view_in_app, :edit_in_app], Institution
      can [:import], [Default, Institution]

      can [:new, :edit], Page
      cannot :edit_in_app, Page

      can :approve, Case
      can [:new], CaseJurisdiction
      can [:create], :case_jurisdictions

      can :show, BulkUpload
    elsif user.has_role? :case_admin
      can [:new, :edit, :update, :show, :export, :export_as, :destroy], Case
      can [:destroy], CaseRequest
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
      can [:index, :show, :export, :export_as, :export_unique, :view_in_app], [Playlist, Collage, TextBlock, Default], :user_id => associated_user_ids
    end
  end
end
