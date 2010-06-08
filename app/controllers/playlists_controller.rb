class PlaylistsController < ApplicationController

  require 'net/http'
  require 'uri'

  include PlaylistUtilities

  before_filter :require_user

  # GET /playlists
  # GET /playlists.xml
  def index
    add_javascripts 'playlist'
    
    @playlists = Playlist.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @playlists }
    end
  end

  # GET /playlists/1
  # GET /playlists/1.xml
  def show
    add_javascripts 'playlist'

    @playlist = Playlist.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @playlist }
    end
  end

  # GET /playlists/new
  # GET /playlists/new.xml
  def new
    add_javascripts 'playlist'
    
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

    @playlist.title = @playlist.output_text.downcase.gsub(" ", "_") unless @playlist.title.present?

    respond_to do |format|
      if @playlist.save

        # If save then assign role as owner to object
        @playlist.accepts_role!(:owner, current_user)

        flash[:notice] = 'Playlist was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@playlist) }
        format.xml  { render :xml => @playlist, :status => :created, :location => @playlist }
      else
        @error_output = "<div class='error ui-corner-all'>"
        @playlist.errors.each{ |attr,msg|
          @error_output += "#{attr} #{msg}<br />"
        }
        @error_output += "</div>"

        format.js {render :text => @error_output, :status => :unprocessable_entity}
        format.html { render :action => "new" }
        format.xml  { render :xml => @playlist.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /playlists/1
  # PUT /playlists/1.xml
  def update
    @playlist = Playlist.find(params[:id])

    respond_to do |format|
      if @playlist.update_attributes(params[:playlist])
        flash[:notice] = 'Playlist was successfully updated.'
        format.html { redirect_to(@playlist) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @playlist.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /playlists/1
  # DELETE /playlists/1.xml
  def destroy
    @playlist = Playlist.find(params[:id])
    @playlist.destroy

    respond_to do |format|
      format.html { redirect_to(playlists_url) }
      format.xml  { head :ok }
    end
  end

  def copy
    @playlist = Playlist.find(params[:id])
  end

  def spawn_copy
    @playlist = Playlist.find(params[:id])  
    @playlist_copy = Playlist.new(params[:playlist])
    if @playlist_copy.title.blank? then @playlist_copy.title = params[:playlist][:output_text] end

    respond_to do |format|
      if @playlist_copy.save
        @playlist_copy.accepts_role!(:owner, current_user)
        @playlist_copy.playlist_items << @playlist.playlist_items.collect { |item| item.clone }

        format.html {
          render :update do |page|
            page << "window.location.replace('#{polymorphic_path(@playlist_copy)}');"
          end
        }
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

    url = URI.parse(test_url)

    object_hash = identify_object(test_url)

    return_hash["host"] = url.host
    return_hash["port"] = url.port
    return_hash["type"] = object_hash["type"]

    if return_hash["type"] == "ItemText" then return_hash["body"] = object_hash["body"] end

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
    return_hash = Hash.new
    
    playlist_order = (params[:playlist_order].split("&"))
    playlist_order.collect!{|x| x.gsub("playlist_item[]=", "")}

    playlist_order.each_index do |item_index|
      PlaylistItem.update(playlist_order[item_index], :position => item_index + 1)
    end


    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end

  end

end
