class PlaylistItemsController < BaseController
  cache_sweeper :playlist_item_sweeper
  protect_from_forgery except: :destroy

  def new
    klass = params[:klass] == "media" ? Media : params[:klass].classify.constantize
    @actual_object = klass.where(id: params[:id]).first
    @playlist_item = PlaylistItem.new({ :playlist_id => params[:playlist_id], 
                                        :position => params[:position], 
                                        :actual_object_type => @actual_object.class.to_s, 
                                        :actual_object_id => @actual_object.id,
                                        :name => @actual_object.name })

    if @actual_object.class == Default
      @url_display = @actual_object.url
    elsif @actual_object.class == Collage
      @playlist_item.description = @actual_object.description
    end
    
    render :partial => "shared/forms/playlist_item"
  end

  def create
    playlist_item = PlaylistItem.new(playlist_item_params)
    playlist_item.position ||= playlist_item.playlist.total_count
    playlist_item_index = playlist_item.position
    playlist_item.position += playlist_item.playlist.counter_start

    if playlist_item.save
      if params.has_key?("on_playlist_page")
        playlist_items = PlaylistItem.unscoped.where(playlist_id: playlist_item.playlist_id)

        playlist_items.each_with_index do |pi, index|
          if pi != playlist_item && (index + 1) >= playlist_item.position
            pi.update_column(:position, pi.position + 1)
          end
        end
 
        if playlist_item.actual_object_type == "Playlist"
          nested_ps = Playlist.includes(:playlist_items).where(id: playlist_item.actual_object.all_actual_object_ids[:Playlist])
          @nested_playlists = nested_ps.inject({}) { |h, p| h["Playlist-#{p.id}"] = p; h }
          @nested_playlists["Playlist-#{playlist_item.actual_object_id}"] = playlist_item.actual_object
        end
        content = render_to_string("shared/objects/_playlist_item.html.erb", :locals => { :item => playlist_item,
          :actual_object => playlist_item.actual_object,
          :parent_index => '', 
          :index => '',
          :position => playlist_item_index,
          :recursive_level => 0 })
  
        render :json => { :playlist_item_id => playlist_item.id, 
                          :error => false, 
                          :total_count => playlist_items.size,
                          :public_count => playlist_items.select { |pi| pi.public_notes }.size,
                          :private_count => playlist_items.select { |pi| !pi.public_notes }.size,
                          :content => content }
      else
        render :json => { :type => "playlists", :id => playlist_item.playlist_id }
      end

    else
      render :json => { :message => "We could not add that playlist item: #{playlist_item.errors.full_messages.join('<br />')}", :error => true }
    end
  end

  def edit
    render :partial => "shared/forms/playlist_item"
  end

  def update
    playlist = @playlist_item.playlist

    if @playlist_item.actual_object_type == "Playlist"
      @nested_playlists = {}
    end

    if @playlist_item.update_attributes(playlist_item_params)
      content = render_to_string("shared/objects/_playlist_item.html.erb", :locals => { :item => @playlist_item,
        :actual_object => @playlist_item.actual_object,
        :parent_index => '', 
        :index => '',
        :position => @playlist_item.position,
        :recursive_level => 4 }
      )
      render :json => { :content => content,
                        :total_count => playlist.total_count,
                        :public_count => playlist.public_count,
                        :private_count => playlist.private_count
                      }
    else
      render :json => { :error => @playlist_item.errors }
    end
  end
  
  def destroy
    playlist_item = PlaylistItem.unscoped.where(id: params[:id]).first
  
    if playlist_item.nil?
      render :json => {}
      return
    end

    playlist = Playlist.where(id: playlist_item.playlist_id).first
    position = playlist_item.position

    if playlist_item.destroy
      playlist_items = PlaylistItem.unscoped.where(playlist_id: playlist.id).where("position > ?", position).order(:position)
      playlist_items.each do |pi|
        pi.update_column(:position, pi.position - 1)
      end
      render :json => { :type => 'playlist_item', 
                        :total_count => playlist_items.size,
                        :public_count => playlist_items.select { |pi| pi.public_notes }.size,
                        :private_count => playlist_items.select { |pi| !pi.public_notes }.size
                    }
    end
  end

  private
  def playlist_item_params
    params.require(:playlist_item).permit(:name, :description, :position, 
                                          :playlist_id, :notes, :public_notes, 
                                          :actual_object_type, :actual_object_id)
  end
end
