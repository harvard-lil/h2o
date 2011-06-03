class BaseController < ApplicationController

  def settings
    add_javascripts 'base'

    @playlists = current_user.roles.find(:all, :conditions => {:name => "owner", :authorizable_type => "Playlist"}).collect(&:authorizable).compact
    @rotisserie_instances = current_user.roles.find(:all, :conditions => {:name => "owner", :authorizable_type => "RotisserieInstance"}).collect(&:authorizable).compact
    @rotisserie_discussions = current_user.roles.find(:all, :conditions => {:name => "owner", :authorizable_type => "RotisserieDiscussion"}).collect(&:authorizable).compact

  end

  def raise_error
    asdfasdfasdf
#    render :text => '', :status => :internal_server_error
  end

  def update_role
    return_hash = Hash.new
    new_role = params[:role_string]

    if User::MANAGEMENT_ROLES.include?(new_role)
      Role.update(params[:object_id], :name => new_role)
    end

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end
  end

  def update_visibility
    return_hash = Hash.new
    identifier_array = params[:object_identifier].split("-")
    public_value = params[:public_value] == "true" ? true : false
    object_class = identifier_array[0].classify.constantize
    object_id = identifier_array[1]
    
    object_class.update(object_id, :public => public_value)

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end
  end

  def preview_textile_content
    render :text => Annotation.format_content(params[:data]), :layout => false
  end

  def preview_html_content
    render :text => Annotation.format_html(params[:data]), :layout => false
  end

  def preview_css_content
    render :text => Annotation.format_content(params[:data]), :layout => false
  end

  def playlist_admin_preload
    if current_user
      @playlist_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','playlist_admin','superadmin']}).length > 0
      @playlists_i_can_edit = current_user.playlists_i_can_edit
    end
  end

  def embedded_pager(model = Case)
    @objects = Sunspot.new_search(model)
    @objects.build do
      unless params[:keywords].blank?
        keywords params[:keywords]
      end
      paginate :page => params[:page], :per_page => cookies[:per_page] || nil
      #      data_accessor_for(model).include = [:tags, :collages, :case_citations]
      order_by :display_name, :asc
    end

    @objects.execute!
    respond_to do |format|
      format.html # index.html.erb
      format.js { render :partial => 'shared/playlistable_item', :object => model }
      format.xml { render :xml => @objects }
    end
  end

  def index
    tcount = Case.find_by_sql("SELECT COUNT(*) AS tcount FROM taggings")
    @counts = {
		:cases => Case.count,
		:text_blocks => TextBlock.count,
		:collages => Collage.count,
		:annotation => Annotation.count,
		:questions => Question.count,
		:rotisseries => RotisserieInstance.count,
		:taggings => tcount[0]['tcount'] 
	}
  end
end
