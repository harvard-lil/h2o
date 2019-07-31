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
      can :create, :responses

      can :destroy, :user_sessions
      can [:verification_request, :verify], :users
      can :new, [Content::Casebook, TextBlock, Default]
      can :create, [:casebooks, :text_blocks, :defaults]
      can :copy, Default, :public => true
      can :copy, Default, :user_id => user.id

      # Can do things on owned items
      if !user.has_role? :superadmin
        can [:edit, :show, :update, :destroy, :export, :export_as, :export_unique], [TextBlock, Default], :user_id => user.id
      end

      can :destroy, Response do |response|
        response.resource.user == user
      end

      # superadmins can edit/update any id, not just their own
      if !user.has_role? :superadmin
        can [:edit, :update], User, :id => user.id
      end
    end

    if user.has_role? :superadmin
      can :access, :rails_admin
      can [:create], :"ckeditor/pictures"
      can [:create], :"ckeditor/assets"
      can [:create], :"ckeditor/attachment_files"
      can :dashboard, :all
      can [:index, :show, :export, :export_as, :export_unique, :bulk_delete, :destroy, :edit, :update, :position_update, :update_notes, :save_readable_state], :all
      can [:edit, :update, :grant_admin], User
      can [:import], [Default]
      can :show_in_app, [Case, User, Content::Casebook]
      can [:new, :edit], Page
      can :approve, Case
      can [:new, :create], CaseCourt
      can [:new, :edit, :update, :show], [Case, CaseCourt, Default, TextBlock, User]
      can :manage_collaborators, [Content::Casebook]

    elsif user.has_role? :case_admin
      can :access, :rails_admin
      can [:index, :show, :export, :export_as, :export_unique, :show_in_app], Case
      can :dashboard, :all

      can [:new, :show, :export, :export_as], Case
      can :create, :cases

      can :approve, Case
      can [:new, :create], CaseCourt
      # Add functionality, ability to modify case requests

    elsif user.has_role? :rep
      user_ids = []
      associated_user_ids = user_ids.flatten.uniq
      can :access, :rails_admin
      can :dashboard, :all
      can [:index, :show, :export, :export_as, :export_unique, show_in_app], [TextBlock, Default], :user_id => associated_user_ids
    end
  end
end
