require 'net/http'
require 'uri'

class PlaylistsController < BaseController
  protect_from_forgery except: [:position_update, :private_notes, :public_notes, :destroy, :copy, :deep_copy, :toggle_nested_private]
  
  cache_sweeper :playlist_sweeper
  caches_page :show, :export, :if => Proc.new { |c| c.instance_variable_get('@playlist').present? && c.instance_variable_get('@playlist').public? }

  def embedded_pager
    super Playlist
  end

  def access_level 
    if current_user
      can_edit = current_user.has_role?(:superadmin) || @playlist.owner?
      can_position_update = can_edit || current_user.can_permission_playlist("position_update", @playlist)
      can_edit_notes = can_edit || current_user.can_permission_playlist("edit_notes", @playlist)
      can_edit_desc = can_edit || current_user.can_permission_playlist("edit_descriptions", @playlist)

      playlist_items = PlaylistItem.unscoped.where(playlist_id: @playlist.id)
      notes = can_edit_notes ? playlist_items : playlist_items.select { |pi| !pi.public_notes }
      nested_private_count_owned = 0
      nested_private_count_nonowned = 0
      if can_edit
        nested_private_resources = @playlist.nested_private_resources
        nested_private_count_owned = nested_private_resources.select { |i| i.user_id == @playlist.user_id }.size
        nested_private_count_nonowned = nested_private_resources.size - nested_private_count_owned
      end
      render :json => {
        :can_edit                       => can_edit,
        :notes                          => can_edit_notes ? notes.to_json(:only => [:id, :notes, :public_notes]) : "[]",
        :can_position_update            => can_position_update,
        :can_edit_notes                 => can_edit_notes,
        :custom_block                   => 'playlist_afterload',
        :can_edit_desc                  => can_edit_desc,
        :nested_private_count_owned     => nested_private_count_owned,
        :nested_private_count_nonowned  => nested_private_count_nonowned,
        :is_superadmin                  => current_user.has_role?(:superadmin)
      }
    else
      render :json => {
        :can_edit             => false,
        :notes                => [],
        :can_position_update  => false,
        :can_edit_notes       => false,
        :custom_block         => 'playlist_afterload',
        :can_edit_desc        => false, 
        :is_superadmin        => false
      }
    end
  end

  def index
    common_index Playlist
  end

  # GET /playlists/1
  def show
    nested_ps = Playlist.includes(:playlist_items).where(id: @playlist.all_actual_object_ids[:Playlist])
    @nested_playlists = nested_ps.inject({}) { |h, p| h["Playlist-#{p.id}"] = p; h }

    @page_cache = true if @playlist.public?
    @editability_path = access_level_playlist_path(@playlist)
    @author_playlists = @playlist.user.playlists.paginate(:page => 1, :per_page => 5)
    @can_edit = current_user && (current_user.has_role?(:superadmin) || @playlist.owner?)
  end

  # GET /playlists/new
  def new
    @playlist = Playlist.new
    @can_edit_all = @can_edit_desc = true
  end

  def edit
    if @playlist.nil? || @playlist.user.nil?
      redirect_to root_url
      return
    end

    if current_user
      @can_edit_all = current_user.has_role?(:superadmin) || @playlist.owner?
      @can_edit_desc = @can_edit_all || current_user.can_permission_playlist("edit_descriptions", @playlist)
    else
      @can_edit_all = @can_edit_desc = false
    end
  end

  # POST /playlists
  def create
    @playlist = Playlist.new(playlist_params)
    @playlist.user = current_user
    verify_captcha(@playlist)

    if @playlist.save
      #IMPORTANT: This reindexes the item with author set
      @playlist.index!

      render :json => { :type => 'playlists', :id => @playlist.id, :modify_playlists_cookie => true, :name => @playlist.name }
    else
      render :json => { :type => 'playlists', :id => @playlist.id, :error => true, :message => "Could not create playlist, with errors: #{@playlist.errors.full_messages.join(',')}" }
    end
  end

  # PUT /playlists/1
  def update
    if current_user
      can_edit_all = current_user.has_role?(:superadmin) || @playlist.owner?
      can_edit_desc = can_edit_all || current_user.can_permission_playlist("edit_descriptions", @playlist)
    else
      can_edit_all = can_edit_desc = false
    end
    if !can_edit_all
      params["playlist"].delete("name")  
      params["playlist"].delete("tag_list")  
      params["playlist"].delete("when_taught")
      params["playlist"].delete("location_id")
    end

    if @playlist.update_attributes(playlist_params)
      render :json => { :type => 'playlists', :id => @playlist.id }
    else
      render :json => { :type => 'playlists', :id => @playlist.id, :error => true, :message => "#{@playlist.errors.full_messages.join(', ')}" }
    end
  end

  def destroy
    @playlist.destroy

    render :json => { :success => true, :id => params[:id].to_i }
  rescue Exception => e
    render :json => { :success => false, :error => "Could not delete #{e.inspect}" }
  end

  def push
    if request.get?
      @collections = current_user.present? ? current_user.collections : []
    else    
      @collection = UserCollection.where(id: params[:user_collection_id]).first
      @playlist_pusher = PlaylistPusher.new(:playlist_id => @playlist.id, :user_ids => @collection.users.map(&:id))
      @playlist_pusher.delay.push!
      respond_to do |format|
        format.json { render :json => {:custom_block => 'push_playlist'} }
        format.js { render :text => nil }
        format.html { redirect_to(playlists_url) }
      end      
    end
  end
 
  def deep_copy
    @playlist_pusher = PlaylistPusher.new(:playlist_id => params[:id], 
                                          :user_ids => [current_user.id], 
                                          :email_receiver => 'destination',
                                          :playlist_name_override => params[:playlist][:name],
                                          :public_private_override => params[:playlist][:public])
    @playlist_pusher.delay.push!

    render :json => { :custom_block => "deep_remix_response" }
  end

  def copy
    begin
      @playlist = Playlist.where(id: params[:id]).first
      @playlist_copy = Playlist.new(playlist_params)
      @playlist_copy.parent = @playlist
      @playlist_copy.karma = 0
      @playlist_copy.user = current_user
      verify_captcha(@playlist_copy)
 
      if @playlist_copy.save
        # Note: Building empty playlist barcode to reduce cache lookup, optimize
        Rails.cache.fetch("playlist-barcode-#{@playlist_copy.id}", :compress => H2O_CACHE_COMPRESSION) { [] }
  
        @playlist_copy.playlist_items << @playlist.playlist_items.collect { |item| 
          new_item = item.clone
          new_item.save!
          new_item
        }
  
        render :json => { :type => 'playlists', :id => @playlist_copy.id, :modify_playlists_cookie => true, :name => @playlist_copy.name  } 
      else
        render :json => { :type => 'playlists', :message => "Could not create playlist, with errors: #{@playlist_copy.errors.full_messages.join(',')}", :error => true }
      end
    rescue Exception => e
      Rails.logger.warn "Failure in playlist copy: #{e.inspect}"
      render :json => { :type => 'playlists'}, :status => :unprocessable_entity 
    end
  end

  def position_update
    playlist_order = (params[:playlist_order].split("&"))
    playlist_order.collect!{|x| x.gsub("playlist_item[]=", "")}
 
    playlist = Playlist.where(id: params[:id]).first
    playlist_items = PlaylistItem.unscoped.where(playlist_id: params[:id])
    return_hash = {}
    playlist_order.each_index do |item_index|
      pi = playlist_items.detect { |pi| pi.id == playlist_order[item_index].to_i }
      pi.update_column(:position, item_index + playlist.counter_start) if pi.present?
      return_hash[pi.id] = item_index + playlist.counter_start
    end

    render :json => return_hash.to_json
  end

  def export
    all_actual_object_ids = @playlist.all_actual_object_ids
    @preloaded_collages = @preloaded_cases = {}
    [Collage, Case].each do |model|
      item_ids = all_actual_object_ids[model.to_s.to_sym]
      if item_ids.any?
        if model == Collage
          items = model.includes(:annotatable, :color_mappings, :annotations => [:layers, :taggings => :tag]).where(id: item_ids)
          items.each do |item|
            @preloaded_collages["collage#{item.id}"] = item
          end
        elsif model == Case
          items = model.includes(:case_citations, :case_docket_numbers).where(id: item_ids)
          items.each do |item|
            @preloaded_cases["case#{item.id}"] = item
          end
        end
      end
    end

    render :layout => 'print'
  end

  def public_notes
    update_notes(true, @playlist)
  end
  def private_notes
    update_notes(false, @playlist)
  end

  def update_notes(value, playlist)
    playlist.playlist_items.each { |pi| pi.update_attribute(:public_notes, value) } 

    render :json => {  :total_count => playlist.playlist_items.count,
                       :public_count => playlist.public_count,
                       :private_count => playlist.private_count
                     }
  end

  def playlist_lookup
    render :json => { :items => @current_user.playlists.collect { |p| { :display => p.name, :id => p.id } } }
  end

  def toggle_nested_private
    @playlist.toggle_nested_private

    render :json => { :updated_count => @playlist.nested_private_resources.count }
  end

  private
  def playlist_params
    params.require(:playlist).permit(:name, :public, :tag_list, :description, :counter_start)
  end
end
