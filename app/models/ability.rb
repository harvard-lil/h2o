class Ability
  include CanCan::Ability

  def initialize(user)
    if user.nil?
      # user can't do anything
    elsif user.has_role? :superadmin
      can :access, :rails_admin
      can :dashboard, :all
      can [:index, :export, :bulk_delete, :destroy, :view_in_app, :edit_in_app], :all
      can [:show, :edit, :new], Institution
      cannot [:view_in_app, :edit_in_app], Institution
      can [:import], [Default, Institution]
    elsif user.has_role? :rep
      user_ids = []
      user.institutions.each do |institution|
        user_ids << institution.users.collect { |u| u.id }
      end
      associated_user_ids = user_ids.flatten.uniq
      can :access, :rails_admin
      can :dashboard, :all
      can [:index, :export, :bulk_delete, :destroy, :view_in_app, :edit_in_app], [Playlist, Collage, Case, TextBlock, Media, Default], :user_id => associated_user_ids
    end
  end
end
