require 'net/http'
require 'uri'

class PlaylistsController < BaseController
  protect_from_forgery except: [:position_update, :private_notes, :public_notes, :destroy, :copy, :toggle_nested_private, :submit_import]
  
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
    return if redirect_bad_format
  
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
 
  def copy
    @playlist_pusher = PlaylistPusher.new(:playlist_id => params[:id], 
                                          :user_ids => [current_user.id], 
                                          :email_receiver => 'destination',
                                          :playlist_name_override => params[:playlist][:name],
                                          :public_private_override => params[:playlist][:public])
    @playlist_pusher.push!

    render :json => { :custom_block => "playlist_clone_response" }
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

  def export_as
    result = PlaylistExporter.export_as(request.url, cookies, params)
    # logger.debug "result.success?: " + result.success?.to_s
    # logger.debug "result.class: " + result.class.to_s
    # logger.debug "result.content_path: " + result.content_path.to_s
    # logger.debug "result.suggested_filename: " + result.suggested_filename.to_s
    if result.success?
      send_file(
                result.content_path,
                filename: result.suggested_filename,
                )
    else
      render :text => result.error_message, :status => :error
    end
  end

  def export
    all_actual_object_ids = @playlist.all_actual_object_ids
    @preloaded_collages = prepare_collage_export(all_actual_object_ids[:Collage])
    @preloaded_cases = prepare_case_export(all_actual_object_ids[:Case])
    if (!params[:load_all])
      #load arbitrary number of items to give the user some idea of how things look
      #set to nil to not set any limit
      @playlist_items_limit = 15
    end
    @playlist_items_count = 0

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

  def import
  end

  def submit_import
    results = validate_nested(params["data"]["0"])
    if results[:errors].any?
      render :json => { :success => false, :message => results[:errors].join('. ') }
    else
      parent_playlist = create_item_from_import(params["data"]["0"])
      render :json => { :playlist_id => parent_playlist.id, :success => true }
    end
  end

  def validate_nested(data)
    if data.has_key?("user_id")
      if @creation_user
        return { :errors => ["Multiple User IDs submitted: #{@creation_user.id} #{data["user_id"]}"] }
      end
      @creation_user = User.where(id: data["user_id"]).first
      if !@creation_user
        return { :errors => ["User not found: #{data["user_id"]}"] }
      end
    end
    if data.has_key?("h2o_item_id")
      existing_item = data["type"].classify.constantize.where(id: data["h2o_item_id"])
      if existing_item.empty?
        return { :errors => ["Could not find #{data["type"]} with id #{data["h2o_item_id"]}"], :data => data }
      else
        # MAYBE TODO: Add error message if item is private and not owned by current user
        data["new_item"] = existing_item.first
        return { :errors => [], :data => data }
      end
    end

    if data.has_key?("collage_item_id")
      existing_item = data["collage_item_type"].classify.constantize.where(id: data["collage_item_id"])
      if existing_item.empty?
        return { :errors => ["Could not find #{data["collage_item_type"]} with id #{data["collage_item_id"]} to collage"], :data => data }
      else
        # MAYBE TODO: Add error message if item is private and not owned by current user
        data["new_item"] = Collage.new({ :name => existing_item.first.is_a?(Case) ? existing_item.first.short_name : existing_item.first.name,
                                         :public => true,
                                         :annotatable_type => data["collage_item_type"].classify,
                                         :annotatable_id => data["collage_item_id"],
                                         :user_id => @creation_user.try(:id) })
        data["new_item"].valid_recaptcha = true
        return { :errors => [], :data => data }
      end
    end

    if data.has_key?("clone_item_id")
      existing_item = data["clone_item_type"].classify.constantize.where(id: data["clone_item_id"])
      if existing_item.empty?
        return { :errors => ["Could not find #{data["clone_item_type"]} with id #{data["clone_item_id"]} to clone"], :data => data }
      else
        existing_item = existing_item.first
        data["new_item"] = existing_item.h2o_clone(@creation_user, { :name => existing_item.name, :description => existing_item.description, :public => true })
        data["new_item"].valid_recaptcha = true
        return { :errors => [], :data => data }
      end
    end

    if data["type"] == 'media'
      klass = Media
    else
      klass = data["type"].classify.constantize
    end

    new_item = klass.new({ 
      :name => data["name"], 
      :description => data["description"], 
      :user_id => @creation_user.try(:id),
      :public => true,
      :created_via_import => true
    })
    new_item.valid_recaptcha = true
    if new_item.is_a?(Default)
      new_item.url = data["url"]
    end
    if new_item.is_a?(Media)
      new_item.media_type = MediaType.where(slug: data["media_type"]).first
    end
    if [Media, TextBlock].any? { |t| new_item.is_a?(t) }
      new_item.content = data["content"]
    end
    item_errors = []
    if !new_item.valid?
      item_errors << "For #{klass.to_s} '#{data["name"]}', #{new_item.errors.full_messages.join(', ')}"
    end
    if data["has_children"] == "true" && data["type"] == "playlist"
      data["children"].each do |a, b|
        results = validate_nested(b)
        item_errors << results[:errors]
      end
    end
    data["new_item"] = new_item
    return { :errors => ["Please supply a User: user_id:XXXXX"] } unless @creation_user
    return { :errors => item_errors.flatten, :data => data }
  end

  def create_item_from_import(data)
    data["new_item"].save
    if data["has_children"] == "true" && data["type"] == "playlist"
      position = 0
      data["children"].each do |a, b|
        child_item = create_item_from_import(b)
        playlist_item = PlaylistItem.create({ :actual_object_id => child_item.id, 
                                           :actual_object_type => child_item.class.to_s, 
                                           :position => position,
                                           :playlist_id => data["new_item"].id })
        position += 1
      end
    end
    return data["new_item"]
  end

  private

  def prepare_collage_export(item_ids)
    return {} if item_ids.nil?

    items = Collage.includes(:annotatable, :color_mappings, :annotations => [:layers, :taggings => :tag]).where(id: item_ids)
    items.inject({}) {|mem, item| mem["collage#{item.id}"] = item; mem }
  end

  def prepare_case_export(item_ids)
    return {} if item_ids.nil?

    items = Case.includes(:case_citations, :case_docket_numbers).where(id: item_ids)
    items.inject({}) {|mem, item| mem["case#{item.id}"] = item; mem }
  end

  def playlist_params
    params.require(:playlist).permit(:name, :public, :primary, :tag_list, :description, :counter_start, :featured)
  end
end
