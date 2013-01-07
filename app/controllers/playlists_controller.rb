require 'net/http'
require 'uri'

class PlaylistsController < BaseController

  include PlaylistUtilities
  
  cache_sweeper :playlist_sweeper

  # TODO: Investigate whether this can be updated to :only => :index, since access_level is being called now
  before_filter :playlist_admin_preload, :except => [:embedded_pager, :metadata, :check_export]
  before_filter :load_playlist, :except => [:metadata, :embedded_pager, :index, :destroy, :export, :check_export]
  before_filter :require_user, :except => [:metadata, :embedded_pager, :show, :index, :export, :access_level, :check_export, :playlist_lookup]
  before_filter :store_location, :only => [:index, :show]
  before_filter :restrict_if_private, :except => [:metadata, :embedded_pager, :index, :new, :create]
  caches_page :show, :export, :if => Proc.new{|c| c.instance_variable_get('@playlist').public?}
  access_control do
    allow all, :to => [:embedded_pager, :show, :index, :export, :access_level, :check_export, :position_update]
    allow logged_in, :to => [:new, :create, :copy, :spawn_copy]

    allow logged_in, :to => [:notes], :if => :allow_notes?
    allow logged_in, :to => [:edit, :update], :if => :allow_edit?

    allow :admin, :playlist_admin, :superadmin
    allow :owner, :of => :playlist
  end

  def allow_notes?
    load_playlist

    current_user.can_permission_playlist("edit_notes", @playlist)
  end

  def allow_edit?
    load_playlist

    current_user.can_permission_playlist("edit_descriptions", @playlist)
  end

  def embedded_pager
    super Playlist
  end

  def access_level 
    session[:return_to] = "/playlists/#{@playlist.id}"
    if current_user
      can_edit = @playlist.admin? || @playlist.owner?
      can_position_update = can_edit || current_user.can_permission_playlist("position_update", @playlist)
      can_edit_notes = can_edit || current_user.can_permission_playlist("edit_notes", @playlist)
      can_edit_desc = can_edit || current_user.can_permission_playlist("edit_descriptions", @playlist)
      notes = can_edit_notes ? @playlist.playlist_items : @playlist.playlist_items.select { |pi| !pi.public_notes }
      render :json => {
        :logged_in            => current_user.to_json(:only => [:id, :login]),
        :can_edit             => can_edit,
        :notes                => can_edit_notes ? notes.to_json(:only => [:id, :notes, :public_notes]) : "[]",
        :playlists            => current_user.playlists.to_json(:only => [:id, :name]),
        :can_position_update  => can_position_update,
        :can_edit_notes       => can_edit_notes,
        :can_edit_desc        => can_edit_desc }
    else
      render :json => {
        :logged_in            => false,
        :can_edit             => false,
        :notes                => [],
        :playlists            => [],
        :can_position_update  => false,
        :can_edit_notes       => false,
        :can_edit_desc        => false }
    end
  end


  def build_search(params)
    playlists = Sunspot.new_search(Playlist)
    
    playlists.build do
      if params.has_key?(:keywords)
        keywords params[:keywords]
      end
      if params.has_key?(:tag)
        with :tag_list, CGI.unescape(params[:tag])
      end
      with :public, true
      paginate :page => params[:page], :per_page => 25

      order_by params[:sort].to_sym, params[:order].to_sym
    end
    playlists.execute!
    playlists
  end

  # GET /playlists
  # GET /playlists.xml
  def index
    params[:page] ||= 1

    if params[:keywords]
      playlists = build_search(params)
      t = playlists.hits.inject([]) { |arr, h| arr.push(h.result); arr }
      @playlists = WillPaginate::Collection.create(params[:page], 25, playlists.total) { |pager| pager.replace(t) }
    else
      @playlists = Rails.cache.fetch("playlists-search-#{params[:page]}-#{params[:tag]}-#{params[:sort]}-#{params[:order]}") do 
        playlists = build_search(params)
        t = playlists.hits.inject([]) { |arr, h| arr.push(h.result); arr }
        { :results => t, 
          :count => playlists.total }
      end
      @playlists = WillPaginate::Collection.create(params[:page], 25, @playlists[:count]) { |pager| pager.replace(@playlists[:results]) }
    end

    if current_user
      @my_playlists = current_user.playlists
      @my_bookmarks = current_user.bookmarks_type(Playlist, ItemPlaylist)
    else
      @my_playlists = @my_bookmarks = []
    end

    respond_to do |format|
      format.html do
        if request.xhr?
          @view = "playlist"
          @collection = @playlists
          render :partial => 'shared/generic_block'
        else
          render 'index'
        end
      end 
      format.xml  { render :xml => @playlists }
    end
  end

  # GET /playlists/1
  # GET /playlists/1.xml
  def show
    respond_to do |format|
      format.html do
        add_javascripts ['playlists', 'jquery.tipsy']
        add_stylesheets 'playlists'

        @can_edit = current_user && (@playlist.admin? || @playlist.owner?)
        @parents = Playlist.find(:all, :conditions => { :id => @playlist.relation_ids })
        (@shown_words, @total_words) = @playlist.collage_word_count
        render 'show' # show.html.erb
      end
      format.xml  { render :xml => @playlist }
    end
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
  # GET /playlists/new.xml
  def new
    @playlist = Playlist.new
    @can_edit_all = @can_edit_desc = true

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @playlist }
    end
  end

  def edit
    if current_user
      @can_edit_all = current_user.has_role?(:superadmin) ||
                      current_user.has_role?(:admin) || 
                      current_user.has_role?(:owner, @playlist)
      @can_edit_desc = @can_edit_all || current_user.can_permission_playlist("edit_descriptions", @playlist)
    else
      @can_edit_all = @can_edit_desc = false
    end
  end

  # POST /playlists
  # POST /playlists.xml
  def create
    @playlist = Playlist.new(params[:playlist])

    @playlist.title = @playlist.name.downcase.gsub(" ", "_") unless @playlist.title.present?

    respond_to do |format|
      if @playlist.save

        # If save then assign role as owner to object
        @playlist.accepts_role!(:owner, current_user)
        @playlist.accepts_role!(:creator, current_user)

        #IMPORTANT: This reindexes the item with author set
        @playlist.index!

        format.js { render :text => nil }
        format.html { redirect_to(@playlist) }
        format.xml  { render :xml => @playlist, :status => :created, :location => @playlist }
        format.json { render :json => { :type => 'playlists', :id => @playlist.id } }
      else
        format.js { 
          render :text => "We couldn't add that playlist. Sorry!<br/>#{@playlist.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity 
        }
        format.html { render :action => "new" }
        format.xml  { render :xml => @playlist.errors, :status => :unprocessable_entity }
        format.json { render :json => { :type => 'playlists', :id => @playlist.id } }
      end
    end
  end

  # PUT /playlists/1
  # PUT /playlists/1.xml
  def update
    if current_user
      can_edit_all = current_user.has_role?(:superadmin) ||
                      current_user.has_role?(:admin) || 
                      current_user.has_role?(:owner, @playlist)
      can_edit_desc = can_edit_all || current_user.can_permission_playlist("edit_descriptions", @playlist)
    else
      can_edit_all = can_edit_desc = false
    end
    if !can_edit_all
      params["playlist"].delete("name")  
      params["playlist"].delete("tag_list")  
    end

    respond_to do |format|
      if @playlist.update_attributes(params[:playlist])
        flash[:notice] = 'Playlist was successfully updated.'
        format.html { redirect_to(@playlist) }
        format.xml  { render :xml => @playlist, :status => :created, :location => @playlist }
        format.json { render :json => { :type => 'playlists', :id => @playlist.id } }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @playlist.errors, :status => :unprocessable_entity }
        format.json { render :json => { :type => 'playlists', :id => @playlist.id } }
      end
    end
  end

  # DELETE /playlists/1
  # DELETE /playlists/1.xml
  def destroy
    @playlist = Playlist.find(params[:id])
    @playlist.destroy

    respond_to do |format|
      format.json { render :json => {} }
      format.js { render :text => nil }
      format.html { redirect_to(playlists_url) }
      format.xml  { head :ok }
    end
  rescue Exception => e
    respond_to do |format|
      format.json { render :json => {} }
      format.js { render :text => "We couldn't delete that, most likely because it's already been deleted.", :status => :unprocessable_entity }
      format.html {  }
      format.xml  { render :status => :unprocessable_entity }
    end
  end

  def copy
    @playlist = Playlist.find(params[:id])
  end

  def metadata
    @playlist = Playlist.find(params[:id])

    @playlist[:object_type] = @playlist.class.to_s
    @playlist[:child_object_name] = 'playlist_item'
    @playlist[:child_object_plural] = 'playlist_items'
    @playlist[:child_object_count] = @playlist.playlist_items.length
    @playlist[:child_object_type] = 'PlaylistItem'
    @playlist[:child_object_ids] = @playlist.playlist_items.collect(&:id).compact
    @playlist[:title] = @playlist.name
    render :xml => @playlist.to_xml(:skip_types => true)
  end

  def spawn_copy
    @playlist = Playlist.find(params[:id])  
    @playlist_copy = Playlist.new(params[:playlist])
    @playlist_copy.parent = @playlist

    if @playlist_copy.title.blank?
      @playlist_copy.title = params[:playlist][:name] 
    end

    respond_to do |format|
      if @playlist_copy.save
        @playlist_copy.accepts_role!(:owner, current_user)
        @playlist.creators && @playlist.creators.each do|c|
          @playlist_copy.accepts_role!(:original_creator,c)
        end
        @playlist_copy.playlist_items << @playlist.playlist_items.collect { |item| 
          new_item = item.clone
          new_item.resource_item = item.resource_item.clone
          item.creators && item.creators.each do|c|
            new_item.accepts_role!(:original_creator,c)
          end
          new_item.accepts_role!(:owner, current_user)
          new_item.playlist_item_parent = item
          new_item
        }

        create_influence(@playlist, @playlist_copy)
        flash[:notice] = "Your copy is below. Cheers!"

        format.html {
          #This is because the post is an ajax submit. . . 
          render :update do |page|
            page << "window.location.replace('#{polymorphic_path(@playlist_copy)}');"
          end
        }
        format.json { render :json => { :type => 'playlists', :id => @playlist_copy.id } } 
        format.xml  { head :ok }
      else
        @error_output = "<div class='error ui-corner-all'>"
        @playlist_copy.errors.each{ |attr,msg|
          @error_output += "#{attr} #{msg}<br />"
        }
        @error_output += "</div>"

        format.js {render :text => @error_output, :status => :unprocessable_entity}
        format.html { render :action => "new" }
        format.xml  { render :xml => @playlist_copy.errors, :status => :unprocessable_entity }
      end
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

    # logger.warn(return_hash.inspect)

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end
  end

  def position_update
    can_position_update = @playlist.admin? || @playlist.owner? || current_user.can_permission_playlist("position_update", @playlist)

    if !can_position_update
      # TODO: Add permissions message here
      render :json => {}
      return
    end

    playlist_order = (params[:playlist_order].split("&"))
    playlist_order.collect!{|x| x.gsub("playlist_item[]=", "")}
     
    playlist_order.each_index do |item_index|
      PlaylistItem.update(playlist_order[item_index], :position => item_index + 1)
    end

    return_hash = @playlist.playlist_items.inject({}) { |h, i| h[i.id] = i.position.to_s; h }

    render :json => return_hash.to_json
  end

  def load_playlist
    unless params[:id].nil?
      @playlist = Playlist.find(params[:id])
    end  
  end

  def export
    @playlist = Playlist.find(params[:id])
    render :layout => 'print'
  end

  def notes
    value = params[:type] == 'public' ? true : false
    @playlist.playlist_items.each { |pi| pi.update_attribute(:public_notes, value) } 

    respond_to do |format|
      format.json {render :json => {} }
    end
  end

  def playlist_lookup
    render :json => { :items => @current_user.playlists.collect { |p| { :display => p.name, :id => p.id } } }
  end

end
