class PlaylistItemsController < BaseController
  cache_sweeper :playlist_item_sweeper
  protect_from_forgery except: :destroy

  def show
    render :partial => 'shared/objects/playlist_item',
      :locals => { :item => @playlist_item,
      :actual_object => @playlist_item.actual_object,
      :parent_index => '', 
      :index => params[:playlist_index],
      :recursive_level => 0,
      :last => false }
  end

  def new
    @can_edit_all = @can_edit_desc = true
    @can_edit_notes = false

    klass = params[:klass] == "media" ? Media : params[:klass].classify.constantize
    @actual_object = klass.where(id: params[:id]).first
    @playlist_item = PlaylistItem.new({ :playlist_id => params[:playlist_id], 
                                        :position => params[:position], 
                                        :actual_object_type => @actual_object.class.to_s, 
                                        :actual_object_id => @actual_object.id })

    if @actual_object.class == Default
      @url_display = @actual_object.url
    elsif @actual_object.class == Collage
      @playlist_item.name = @actual_object.name
      @playlist_item.description = @actual_object.description
    elsif @actual_object.class == Playlist
      @playlist_item.name = @actual_object.root.name
    end
    
    render :partial => "shared/forms/playlist_item"
  end

  def create
    playlist_item = PlaylistItem.new(playlist_item_params)
    playlist = playlist_item.playlist
    playlist_item.position ||= playlist_item.playlist.total_count + 1

    position_data = {}
    if playlist_item.save
      playlist_item.playlist.save
      position_data[playlist_item.id.to_s] = playlist_item.position

      playlist_item.playlist.playlist_items.each_with_index do |pi, index|
        if pi != playlist_item && (index + 1) >= playlist_item.position
          position_data[pi.id] = (pi.position + 1).to_s
          pi.update_attribute(:position, pi.position + 1)
        end
      end

	    render :json => { :type => 'playlists', 
                        :playlist_item_id => playlist_item.id, 
                        :playlist_id => playlist_item.playlist.id,
                        :id => playlist_item.playlist.id,
                        :error => false, 
                        :position_data => position_data,
                        :total_count => playlist.total_count,
                        :public_count => playlist.public_count,
                        :private_count => playlist.private_count
                      }
    else
	    render :json => { :message => "We could not add that playlist item: #{playlist_item.errors.full_messages.join('<br />')}", :error => true }
    end
  end

  def edit
    playlist = @playlist_item.playlist

    if current_user
      @can_edit_all = current_user.has_role?(:superadmin) || playlist.owner?
      @can_edit_notes = @can_edit_all || current_user.can_permission_playlist("edit_notes", playlist)
      @can_edit_desc = @can_edit_all || current_user.can_permission_playlist("edit_descriptions", playlist)
    else
      @can_edit_all = @can_edit_notes = @can_edit_desc = false
    end

    render :partial => "shared/forms/playlist_item"
  end

  def update
    playlist = @playlist_item.playlist

    if current_user
      can_edit_all = current_user.has_role?(:superadmin) || playlist.owner?
      can_edit_notes = can_edit_all || current_user.can_permission_playlist("edit_notes", playlist)
      can_edit_desc = can_edit_all || current_user.can_permission_playlist("edit_descriptions", playlist)
    else
      can_edit_all = can_edit_notes = can_edit_desc = false
    end

    if !can_edit_desc 
      params[:playlist_item].delete(:description)
    end

    if !can_edit_notes
      params[:playlist_item].delete(:notes)
      params[:playlist_item].delete(:public_notes)
    else
      params[:playlist_item][:public_notes] = params[:playlist_item][:public_notes] == 'on' ? true : false
    end

    if @playlist_item.update_attributes(playlist_item_params)
      @playlist_item.playlist.save
	    render :json => { :type => 'playlists', 
                        :id => @playlist_item.id, 
                        :name => @playlist_item.name, 
                        :description => @playlist_item.description,
                        :public_notes => @playlist_item.public_notes,
                        :notes => @playlist_item.notes,
                        :total_count => playlist.total_count,
                        :public_count => playlist.public_count,
                        :private_count => playlist.private_count
                      }
    else
	    render :json => { :error => @playlist_item.errors }
    end
  end
  
  def destroy
    playlist = @playlist_item.playlist
    if @playlist_item.destroy
      @playlist_item.playlist.save
      playlist.reset_positions
	    render :json => { :type => 'playlist_item', 
                        :position_data => playlist.playlist_items.inject({}) { |h, i| h[i.id] = i.position.to_s; h },
                        :total_count => playlist.total_count,
                        :public_count => playlist.public_count,
                        :private_count => playlist.private_count
                    }
    end
  end

  private
  def playlist_item_params
    params.require(:playlist_item).permit(:name, :description, :position, 
                                          :playlist_id, :notes, :public_notes, 
                                          :url, :actual_object_type, :actual_object_id)
  end
end
