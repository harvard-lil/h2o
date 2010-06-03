class BaseController < ApplicationController

  def settings
    add_javascripts 'base'

    @playlists = current_user.roles.find(:all, :conditions => {:name => "owner", :authorizable_type => "Playlist"}).collect(&:authorizable).compact
    @rotisserie_instances = current_user.roles.find(:all, :conditions => {:name => "owner", :authorizable_type => "RotisserieInstance"}).collect(&:authorizable).compact
    @rotisserie_discussions = current_user.roles.find(:all, :conditions => {:name => "owner", :authorizable_type => "RotisserieDiscussion"}).collect(&:authorizable).compact

  end

  def update_role
    return_hash = Hash.new
    new_role = params[:role_string]

    if User::MANAGEMENT_ROLES.include?(new_role)
      Role.update(params[:object_id], :name => new_role)
    end

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end

  end

  def update_visibility
    return_hash = Hash.new
    identifier_array = params[:object_identifier].split("-")
    public_value = params[:public_value] == "true" ? true : false
    object_class = identifier_array[0].classify.constantize
    object_id = identifier_array[1]
    
    object_class.update(object_id, :public => public_value)

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end

  end



end
