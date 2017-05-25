class Ability
  include CanCan::Ability

  def initialize(user)
    can [:show, :index], :users
    can :show, :pages
    can [:landing, :index, :author_playlists, :search, :not_found, :load_more_users, :tags], :base
    can [:new, :create, :edit, :update], :password_resets
    can [:new, :create], :login_notifiers
    can [:new, :create], :user_sessions
    can :index, [:cases, :text_blocks, :defaults]

    can [:show, :export, :export_as], Content::Node, :public => true
    can [:show, :export, :export_as], Case, :public => true
    can [:show, :export, :export_as], TextBlock, :public => true

    if user.nil?
      can [:new, :create], :users
      return
    else
      can [:user_lookup, :disconnect_dropbox], :users
      can :create, :responses

      can :destroy, :user_sessions
      can [:bookmark_item, :delete_bookmark_item, :verification_request, :verify], :users
      can :new, [Content::Casebook, TextBlock, Default, CaseRequest]
      can :create, [:casebooks, :text_blocks, :defaults, :case_requests, :bulk_uploads]
      can :copy, Default, :public => true
      can :copy, Default, :user_id => user.id

      can [:embedded_pager, :access_level], :all

      # Can do things on owned items
      if !user.has_role? :superadmin
        can [:edit, :show, :update, :destroy, :export, :export_as, :export_unique], [TextBlock, Default], :user_id => user.id
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
      can [:index, :show, :export, :export_as, :export_unique, :bulk_delete, :destroy, :view_in_app, :edit_in_app, :edit,
           :update, :position_update, :update_notes, :save_readable_state],
        :all
      can :aggregate_items, [TextBlock, Default, User]
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
      can [:index, :show, :export, :export_as, :export_unique, :view_in_app], [TextBlock, Default], :user_id => associated_user_ids
    end
  end
end
