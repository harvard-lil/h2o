require 'net/http'
require 'uri'

class PlaylistsController < BaseController
  protect_from_forgery except: [:position_update, :private_notes, :public_notes, :destroy, :copy, :deep_copy]
  
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
      notes = can_edit_notes ? @playlist.playlist_items : @playlist.playlist_items.select { |pi| !pi.public_notes }
      nested_private_count_owned = 0
      nested_private_count_nonowned = 0
      if can_edit
        nested_private_resources = @playlist.nested_private_resources
        nested_private_count_owned = nested_private_resources.select { |i| i.user_id == @playlist.user_id }.count
        nested_private_count_nonowned = nested_private_resources.count - nested_private_count_owned
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
      @playlist = Playlist.where(id: params[:id]).includes(:playlist_items).first
      @playlist_copy = Playlist.new(playlist_params)
      @playlist_copy.parent = @playlist
      @playlist_copy.karma = 0
      @playlist_copy.user = current_user
      # FIXME: Captcha not working here
      @playlist_copy.valid_recaptcha = true
 
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
     
    playlist_order.each_index do |item_index|
      PlaylistItem.update(playlist_order[item_index], :position => item_index + 1)
    end

    return_hash = @playlist.playlist_items.inject({}) { |h, i| h[i.id] = i.position.to_s; h }

    render :json => return_hash.to_json
  end

  def export
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
