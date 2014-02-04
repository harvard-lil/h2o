require 'net/http'
require 'uri'

class PlaylistsController < BaseController

  include PlaylistUtilities
  
  cache_sweeper :playlist_sweeper
  caches_page :show, :export, :if => Proc.new{|c| c.instance_variable_get('@playlist').public?}

  # TODO: Investigate whether this can be updated to :only => :index, since access_level is being called now
  before_filter :load_single_resource, :except => [:embedded_pager, :index, :destroy, :check_export, :toggle_nested_private]
  before_filter :require_user, :except => [:embedded_pager, :show, :index, :export, :access_level, :check_export, :playlist_lookup]
  before_filter :restrict_if_private, :except => [:embedded_pager, :index, :new, :create, :destroy]

  access_control do
    allow all, :to => [:embedded_pager, :show, :index, :export, :access_level, :check_export]

    allow logged_in, :to => [:new, :create, :copy, :deep_copy]
    allow logged_in, :to => [:notes], :if => :allow_notes?
    allow logged_in, :to => [:edit, :update], :if => :allow_edit?

    allow logged_in, :if => :is_owner?

    allow :superadmin
  end

  def allow_notes?
    load_single_resource

    current_user.can_permission_playlist("edit_notes", @playlist)
  end

  def allow_edit?
    load_single_resource

    current_user.can_permission_playlist("edit_descriptions", @playlist)
  end

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
    add_javascripts ['playlists', 'jquery.tipsy', 'jquery.nestable']
    add_stylesheets ['playlists']


    @author_playlists = @playlist.user.playlists.paginate(:page => 1, :per_page => 5)
    @can_edit = current_user && (current_user.has_role?(:superadmin) || @playlist.owner?)
  end

  def check_export
    cgi = request.query_parameters.delete_if { |k, v| k == "_" }.to_query
    clean_cgi = CGI.escape(cgi)
    if FileTest.exists?("#{RAILS_ROOT}/tmp/cache/playlist_#{params[:id]}.pdf?#{clean_cgi}")
      render :json => {}, :status => 200
    else
      render :json => {}, :status => 404
    end
  end

  # GET /playlists/new
  def new
    @playlist = Playlist.new
    @can_edit_all = @can_edit_desc = true
  end

  def edit
    if current_user
      @can_edit_all = current_user.has_role?(:superadmin) || @playlist.owner?
      @can_edit_desc = @can_edit_all || current_user.can_permission_playlist("edit_descriptions", @playlist)
    else
      @can_edit_all = @can_edit_desc = false
    end
  end

  # POST /playlists
  def create
    @playlist = Playlist.new(params[:playlist])

    @playlist.title = @playlist.name.downcase.gsub(" ", "_") unless @playlist.title.present?
    @playlist.user = current_user

    if @playlist.save
      #IMPORTANT: This reindexes the item with author set
      @playlist.index!

      render :json => { :type => 'playlists', :id => @playlist.id, :modify_playlists_cookie => true, :name => @playlist.name }
    else
      render :json => { :type => 'playlists', :id => @playlist.id }
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

    if @playlist.update_attributes(params[:playlist])
      render :json => { :type => 'playlists', :id => @playlist.id }
    else
      render :json => { :type => 'playlists', :id => @playlist.id, :error => true, :message => "#{@playlist.errors.full_messages.join(', ')}" }
    end
  end

  # DELETE /playlists/1
  def destroy
    @playlist = Playlist.find(params[:id])
    @playlist.destroy

    render :json => { :success => true, :id => params[:id].to_i }
  rescue Exception => e
    render :json => { :success => false, :error => "Could not delete #{e.inspect}" }
  end

  def push  
    if request.get?
      @playlist = Playlist.find(params[:id])    
      @collections = current_user.collections
    else    
      @collection = UserCollection.find(params[:user_collection_id])
      @playlist = Playlist.find(params[:id])
      @playlist_pusher = PlaylistPusher.new(:playlist_id => @playlist.id, :user_ids => @collection.users.map(&:id))
      @playlist_pusher.delay.push!
      respond_to do |format|
        format.json { render :json => {:custom_block => 'push_playlist'} }
        format.js { render :text => nil }
        format.html { redirect_to(playlists_url) }
        format.xml  { head :ok }
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
      @playlist = Playlist.find(params[:id], :include => :playlist_items)  
      @playlist_copy = Playlist.new(params[:playlist])
      @playlist_copy.parent = @playlist
      @playlist_copy.karma = 0
      @playlist_copy.title = params[:playlist][:name]
      @playlist_copy.user = current_user
 
      if @playlist_copy.save
        # Note: Building empty playlist barcode to reduce cache lookup, optimize
        Rails.cache.fetch("playlist-barcode-#{@playlist_copy.id}") { [] }
  
        @playlist_copy.playlist_items << @playlist.playlist_items.collect { |item| 
          new_item = item.clone
          new_item.save!
          new_item
        }
  
        render :json => { :type => 'playlists', :id => @playlist_copy.id, :modify_playlists_cookie => true, :name => @playlist_copy.name  } 
      else
        render :json => { :type => 'playlists'}, :status => :unprocessable_entity 
      end
    rescue Exception => e
      Rails.logger.warn "Failure in playlist copy: #{e.inspect}"
      render :json => { :type => 'playlists'}, :status => :unprocessable_entity 
    end
  end

  def url_check
    return_hash = Hash.new
    test_url = params[:url_string]
    return_hash["url_string"] = test_url
    return_hash["description_string"]

    uri = URI.parse(test_url)

    object_hash = identify_object(test_url,uri)

    return_hash["host"] = uri.host
    return_hash["port"] = uri.port
    return_hash["type"] = object_hash["type"]
    return_hash["body"] = object_hash["body"]

    render :json => return_hash.to_json
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
    add_javascripts ['json2', 'annotator-full', 'h2o-annotator']
    add_stylesheets 'annotator.min'
    render :layout => 'print'
  end

  def notes
    value = params[:type] == 'public' ? true : false
    @playlist.playlist_items.each { |pi| pi.update_attribute(:public_notes, value) } 

    render :json => {  :total_count => @playlist.playlist_items.count,
                       :public_count => @playlist.public_count,
                       :private_count => @playlist.private_count
                     }
  end

  def playlist_lookup
    render :json => { :items => @current_user.playlists.collect { |p| { :display => p.name, :id => p.id } } }
  end

  def toggle_nested_private
    @playlist.toggle_nested_private

    render :json => { :updated_count => @playlist.nested_private_resources.count }
  end
end
