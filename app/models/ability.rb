class Ability
  include CanCan::Ability

  def initialize(user)
    can [:show, :index], :users
    can :show, :pages
    can [:landing, :index, :search, :not_found], :base
    can [:new, :create, :edit, :update], :password_resets
    can [:new, :create], :user_sessions
    can :index, [:cases, :text_blocks, :links]

    can [:show, :export], [Content::Node, Case, TextBlock], :public => true
    # can [:show, :export], Case, :public => true
    # can [:show, :export], TextBlock, :public => true

    if user.nil?
      can [:new, :create], :users
      return
    else
      can :destroy, :user_sessions
      can [:verification_request, :verify], :users
      can :new, [Content::Casebook, TextBlock, Link]
      can :create, [:casebooks, :text_blocks, :links]
      can :copy, Link, :public => true
      can :copy, Link, :user_id => user.id

      # Can do things on owned items
      if !user.has_role? :superadmin
        can [:edit, :show, :update, :destroy, :export], [TextBlock, Link], :user_id => user.id
      end

      # superadmins can edit/update any id, not just their own
      if !user.has_role? :superadmin
        can [:edit, :update], User, :id => user.id
      end
    end

    if user.has_role? :superadmin
      can [:edit, :update], User
      can :access, :rails_admin
      can [:create], [:"ckeditor/pictures", :"ckeditor/assets", :"ckeditor/attachment_files"]
      can :dashboard, :all
      can [:index, :show, :export, :export_as, :export_unique, :bulk_delete, :destroy, :edit, :update, :position_update, :update_notes, :save_readable_state], :all
      can [:import], [Link]
      can :show_in_app, [Case, User, Content::Casebook]
      can [:new, :edit], Page
      can [:new], CaseCourt
      can [:create], :case_courts
      can [:new, :edit, :update, :show], [Case, CaseCourt, Link, TextBlock, User]
      can :manage_collaborators, [Content::Casebook]
    end
  end
end
