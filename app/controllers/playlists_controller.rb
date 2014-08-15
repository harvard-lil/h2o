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
      can_edit = can? :edit, @playlist
      playlist_items = PlaylistItem.unscoped.where(playlist_id: @playlist.id)
      nested_private_count_owned = 0
      nested_private_count_nonowned = 0
      if can_edit
        nested_private_resources = @playlist.nested_private_resources
        nested_private_count_owned = nested_private_resources.select { |i| i.user_id == @playlist.user_id }.size
        nested_private_count_nonowned = nested_private_resources.size - nested_private_count_owned
      end
      render :json => {
        :can_edit                       => can_edit,
        :can_destroy                    => can?(:destroy, @playlist),
        :notes                          => can_edit ? playlist_items.to_json(:only => [:id, :notes, :public_notes]) : [].to_json,
        :custom_block                   => 'playlist_afterload',
        :nested_private_count_owned     => nested_private_count_owned,
        :nested_private_count_nonowned  => nested_private_count_nonowned,
        :is_superadmin                  => current_user.has_role?(:superadmin)
      }
    else
      render :json => {
        :can_edit             => false,
        :can_destroy          => false,
        :notes                => [],
        :custom_block         => 'playlist_afterload',
        :is_superadmin        => false
      }
    end
  end

  def index
    common_index Playlist
  end

  def show
    nested_ps = Playlist.includes(:playlist_items).where(id: @playlist.all_actual_object_ids[:Playlist])
    @nested_playlists = nested_ps.inject({}) { |h, p| h["Playlist-#{p.id}"] = p; h }

    @page_cache = true if @playlist.public?
    @editability_path = access_level_playlist_path(@playlist)
    @author_playlists = @playlist.user.playlists.paginate(:page => 1, :per_page => 5)
  end

  def new
    @playlist = Playlist.new
  end

  def edit
    if @playlist.nil? || @playlist.user.nil?
      redirect_to root_url
      return
    end
  end

  def create
    return :json => {} if !params.has_key?(:playlist)

    @playlist = Playlist.new(playlist_params)
    @playlist.user = current_user
    verify_captcha(@playlist)

    if @playlist.save
      #IMPORTANT: This reindexes the item with author set
      @playlist.index!

      render :json => { :type => 'playlists', :id => @playlist.id, :name => @playlist.name }
    else
      render :json => { :type => 'playlists', :id => @playlist.id, :error => true, :message => "Could not create playlist, with errors: #{@playlist.errors.full_messages.join(',')}" }
    end
  end

  def update
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

  # TODO: Is this used?
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
      @playlist_copy.featured = false
      verify_captcha(@playlist_copy)
 
      if @playlist_copy.save
        # Note: Building empty playlist barcode to reduce cache lookup, optimize
        Rails.cache.fetch("playlist-barcode-#{@playlist_copy.id}", :compress => H2O_CACHE_COMPRESSION) { [] }
 
        @playlist.playlist_items.each do |playlist_item|
          new_item = playlist_item.dup
          new_item.playlist_id = @playlist_copy.id
          new_item.save
        end
  
        render :json => { :type => 'playlists', :id => @playlist_copy.id, :name => @playlist_copy.name  } 
      else
        render :json => { :type => 'playlists', :message => "Could not create playlist, with errors: #{@playlist_copy.errors.full_messages.join(',')}", :error => true }
      end
    rescue Exception => e
      Rails.logger.warn "Failure in playlist copy: #{e.inspect}"
      render :json => { :type => 'playlists'}, :status => :unprocessable_entity 
    end
  end

  def position_update
    updates = {}
    ids = []
    params["changed"].each do |k, v|
      updates["pi_#{v["id"]}"] = { :position => v["position"], :playlist_id => v["playlist_id"] }
      ids << v["id"]
    end
  
    mod_playlists = []
    PlaylistItem.unscoped.includes(:playlist).where(id: ids).each do |playlist_item|
      mod_playlists << playlist_item.playlist_id
      updates["pi_#{playlist_item.id}"][:position] = updates["pi_#{playlist_item.id}"][:position].to_i + playlist_item.playlist.counter_start
      playlist_item.update_columns(updates["pi_#{playlist_item.id}"])
    end

    mod_playlists.uniq.each do |playlist_id|
      Playlist.clear_nonsiblings(playlist_id)
    end

    render :json => {}
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
    playlist.playlist_items.each { |pi| pi.update_column(:public_notes, value) }
    ActionController::Base.expire_page "/playlists/#{playlist.id}.html"
    ActionController::Base.expire_page "/playlists/#{playlist.id}/export.html"

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
    params.require(:playlist).permit(:name, :public, :primary, :tag_list, :description, :counter_start, :featured)
  end
end
