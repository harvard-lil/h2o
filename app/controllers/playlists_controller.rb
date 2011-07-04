require 'net/http'
require 'uri'

class PlaylistsController < BaseController

  include PlaylistUtilities

  before_filter :playlist_admin_preload, :except => [:embedded_pager, :metadata]
  before_filter :load_playlist, :except => [:metadata, :embedded_pager, :index, :destroy, :export]
  before_filter :require_user, :except => [:metadata, :embedded_pager, :show, :index, :export]
  before_filter :list_tags, :only => [:index, :show, :edit]
  
  access_control do
    allow all, :to => [:embedded_pager, :show, :index, :export]
    allow logged_in, :to => [:new, :create, :copy, :spawn_copy]
    allow :admin, :playlist_admin, :superadmin
    allow :owner, :of => :playlist
    allow :editor, :of => :playlist, :to => [:edit, :update]
    #    allow :user, :of => :playlist, :to => [:index, :show]
  end

  def embedded_pager
    super Playlist
  end

  def list_tags
    @playlist_tags = Tag.find_by_sql("SELECT ts.tag_id AS id, t.name FROM taggings ts
		JOIN tags t ON ts.tag_id = t.id
		WHERE taggable_type = 'Playlist'
		GROUP BY ts.tag_id, t.name
		ORDER BY COUNT(*) DESC LIMIT 25")
  end

  # GET /playlists
  # GET /playlists.xml
  def index
    @playlists = Sunspot.new_search(Playlist)

	if !params.has_key?(:sort)
	  params[:sort] = "display_name"
	end

    sort_base_url = ''
	@playlists.build do
	  if params.has_key?(:keywords)
	    keywords params[:keywords]
        sort_base_url += "&keywords=#{params[:keywords]}"
	  end
	  if params.has_key?(:tag)
	    with :tag_list, CGI.unescape(params[:tag])
		sort_base_url += "&tag=#{params[:tag]}"
	  end
	  with :public, true
	  paginate :page => params[:page], :per_page => cookies[:per_page] || nil
	  order_by params[:sort].to_sym, :asc
	end

	@playlists.execute!

    build_bookmarks("ItemPlaylist")

    @my_playlists = current_user ? current_user.playlists : []
    
    respond_to do |format|
      format.html do
	    if request.xhr?
		  render :partial => 'playlists_block'
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
    add_javascripts 'playlists'
    add_stylesheets 'playlists'

    @playlist.playlist_items.find(:all, :include => [:resource_item])

    @my_playlist = (current_user) ? current_user.playlists.include?(@playlist) || current_user.bookmark_id == @playlist.id : false

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @playlist }
	  format.pdf do
	    url = request.url.gsub(/\.pdf.*/, "/export")
		file = Tempfile.new("playlist.pdf")
	    cmd = "#{RAILS_ROOT}/wkhtmltopdf #{url} - > #{file.path}"
		system(cmd)
		file.close
		send_file file.path, :filename => "playlist_#{@playlist.id}.pdf", :type => 'application/pdf'
		#file.unlink
		#Removing saved state after used
	  end
    end
  end

  # GET /playlists/new
  # GET /playlists/new.xml
  def new
    @playlist = Playlist.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @playlist }
    end
  end

  # GET /playlists/1/edit
  def edit
    @playlist = Playlist.find(params[:id])
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

        flash[:notice] = 'Playlist was successfully created.'
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
    @playlist = Playlist.find(params[:id])

    respond_to do |format|
      if @playlist.update_attributes(params[:playlist])
        @playlist.accepts_role!(:editor,current_user)
        flash[:notice] = 'Playlist was successfully updated.'
        format.js { render :text => nil}
        format.html { redirect_to(@playlist) }
        format.xml  { render :xml => @playlist, :status => :created, :location => @playlist }
	  	format.json { render :json => { :type => 'playlists', :id => @playlist.id } }
      else
        format.js {
          render :text => "We couldn't update that playlist. Sorry!<br/>#{@playlist.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity
        }
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

  def block
    respond_to do |format|
      format.html {
        render :partial => 'playlists_block',
        :layout => false
      }
      format.xml  { head :ok }
    end
  end

  def url_check
    return_hash = Hash.new
    #test_url = CGI.escape(params[:url_string])
    test_url = params[:url_string]
    return_hash["url_string"] = test_url
    return_hash["description_string"]

    uri = URI.parse(test_url)

    object_hash = identify_object(test_url,uri)

    return_hash["host"] = uri.host
    return_hash["port"] = uri.port
    return_hash["type"] = object_hash["type"]
    return_hash["body"] = object_hash["body"]

    logger.warn(return_hash.inspect)

    #    if return_hash["type"] == "ItemText"
    #      return_hash["body"] = object_hash["body"]
    #    elsif return_hash["type"] == 'ItemQuestionInstance'
    #      return_hash["body"] = 'I am a serious body'
    #    end

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end
  end

  def item_chooser
    respond_to do |format|
      format.html {
        render :partial => 'shared/layout_components/playlist_item_chooser',
        :locals => {
          :url_string => params[:url_string],
          :container_id => params[:container_id],
          :body => params[:body]
        },
        :layout => false
      }
      format.xml  { head :ok }
    end
  end

  def load_form
    item_type = params[:item_type]
    url_string = params[:url_string]
    container_id = params[:container_id]

    respond_to do |format|
      format.html {
        render :partial => 'shared/forms/' + item_type.tableize.singularize, :locals => {
          :item_type => item_type,
          :url_string => url_string,
          :container_id => container_id
        },
        :layout => false
      }
      format.xml  { head :ok }
    end

  end

  def position_update
    playlist_order = (params[:playlist_order].split("&"))
    playlist_order.collect!{|x| x.gsub("playlist_item[]=", "")}

    playlist_order.each_index do |item_index|
      PlaylistItem.update(playlist_order[item_index], :position => item_index + 1)
    end

    return_hash = @playlist.playlist_items.inject({}) { |h, i| h[i.id] = i.position.to_s; h }

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end

  end

  def load_playlist
    unless params[:id].nil?
      @playlist = Playlist.find(params[:id])
    end  
  end

  def export
    @playlist = Playlist.find(params[:id])
    #add_javascripts['export_collage']
	render :layout => 'pdf'
  end
end
