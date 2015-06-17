class PlaylistItemsController < BaseController
  cache_sweeper :playlist_item_sweeper
  protect_from_forgery except: :destroy

  def new
    klass = params[:klass] == "media" ? Media : params[:klass].classify.constantize
    @actual_object = klass.where(id: params[:id]).first

    if @actual_object.nil?
      render :json => {}, :status => :error
      return
    end

    @playlist_item = PlaylistItem.new({ :playlist_id => params[:playlist_id], 
                                        :position => params[:position], 
                                        :actual_object_type => @actual_object.class.to_s, 
                                        :actual_object_id => @actual_object.id })

    render :partial => "shared/forms/playlist_item"
  end

  def create
    playlist_item = PlaylistItem.new(playlist_item_params)
    playlist_item.position ||= playlist_item.playlist.total_count
    playlist_item_index = playlist_item.position
    playlist_item.position += playlist_item.playlist.counter_start

    # Autoclone
    if playlist_item.actual_object_type != 'Case'
      if playlist_item.playlist.user == playlist_item.actual_object.user
        if params[:playlist_item][:name] != playlist_item.actual_object.name ||
           params[:playlist_item][:description] != playlist_item.actual_object.description
          playlist_item.actual_object.update_attributes({ :name => params[:playlist_item][:name], :description => params[:playlist_item][:name] })
        end
      else
        if params[:playlist_item][:name] == playlist_item.actual_object.name &&
           params[:playlist_item][:description] == playlist_item.actual_object.description
          # do nothing special, reference original item
        else
          new_item = playlist_item.actual_object.h2o_clone(current_user, params[:playlist_item])
          new_item.valid_recaptcha = true
          playlist_item.actual_object = new_item
        end
      end
    end
    params[:playlist_item].delete(:name)
    params[:playlist_item].delete(:description)
    # End Autoclone

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

    if @playlist_item.actual_object.nil?
      render :json => { :error => "Could not update playlist item because original item does not exist." }
      return
    end

    # Autoclone
    if @playlist_item.actual_object_type != 'Case'
      if @playlist_item.playlist.user == @playlist_item.actual_object.user
        if params[:playlist_item][:name] != @playlist_item.actual_object.name ||
           params[:playlist_item][:description] != @playlist_item.actual_object.description
          @playlist_item.actual_object.update_attributes({ :name => params[:playlist_item][:name], :description => params[:playlist_item][:description] })
        end
      else
        if params[:playlist_item][:name] == @playlist_item.actual_object.name &&
           params[:playlist_item][:description] == @playlist_item.actual_object.description
          # do nothing special, reference original item
        else
          new_item = @playlist_item.actual_object.h2o_clone(current_user, params[:playlist_item])
          new_item.valid_recaptcha = true
          @playlist_item.actual_object = new_item
        end
      end
    end
    params[:playlist_item].delete(:name)
    params[:playlist_item].delete(:description)
    # End Autoclone

    if @playlist_item.update_attributes(playlist_item_params)
      @nested_playlists = {}
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

  def show
    # This exists to prevent garbage exceptions in the Rails log caused by
    # spam links pointing to this non-existent route, and returns a 404 specifically
    # to detract from spam links' Google juice
    render :text => "Not found", :status => 404, :layout => false
  end

  private
  def playlist_item_params
    params.require(:playlist_item).permit(:position, :playlist_id, :notes, :public_notes, 
                                          :actual_object_type, :actual_object_id)
  end
end
