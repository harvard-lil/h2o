class BaseController < ApplicationController
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
      format.html { render :partial => 'shared/playlistable_item', :object => model }
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

  def search
	if !params.has_key?(:sort)
	  params[:sort] = "display_name"
	end

    sort_base_url = ''
	if params.has_key?(:keywords)
      sort_base_url += "&keywords=#{params[:keywords]}"
	end

    if !params.has_key?(:is_pagination) || params[:is_pagination] == 'playlists'
      @playlists = Sunspot.new_search(Playlist)
	  @playlists.build do
	    if params.has_key?(:keywords)
          keywords params[:keywords]
        end
	    with :public, true
	    paginate :page => params[:page], :per_page => cookies[:per_page] || nil
	    order_by params[:sort].to_sym, :asc
	  end
	  @playlists.execute!
	end

    if !params.has_key?(:is_pagination) || params[:is_pagination] == 'collages'
	  @collages = Sunspot.new_search(Collage)
	  @collages.build do
	    if params.has_key?(:keywords)
	      keywords params[:keywords]
	    end
	    with :public, true
	    with :active, true
	    paginate :page => params[:page], :per_page => cookies[:per_page] || nil

	    # FIGURE OUT IF THE FOLLOWING LINE IS NEEDED
	    data_accessor_for(Collage).include = {:annotations => {:layers => []}, :accepted_roles => {}, :annotatable => {}}

	    order_by params[:sort].to_sym, :asc
	  end
      @collages.execute!
	end


	if current_user
	  @is_collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
	  @my_collages = current_user.collages
	  @my_playlists = current_user.playlists
	else
	  @is_collage_admin = false
	  @my_collages = []
	  @my_playlists = []
	end

    playlist_admin_preload

    generate_sort_list("/search?#{sort_base_url}",
		{	"display_name" => "DISPLAY NAME",
			"created_at" => "BY DATE",
			"author" => "BY AUTHOR"	}
		)
	respond_to do |format|
	  format.html do
	    if params.has_key?(:is_pagination)
		  render :partial => "#{params[:is_pagination]}/#{params[:is_pagination]}_block"
		else
		  render 'search'
		end
	  end
	end
  end

  protected

  def build_bookmarks(type)
	@my_bookmarks = []
	if current_user && current_user.bookmark_id
	  # TODO: Update this to be linked through user / foreign key
	  @my_bookmarks = current_user.bookmarks.inject([]) do |arr, p|
	    logger.warn "steph: #{p.resource_item_type}"
		logger.warn "steph: #{p.resource_item.inspect}"
	    if p.resource_item_type == type && p.resource_item.actual_object
		  logger.warn "steph: adding item"
		  arr << p.resource_item.actual_object
		end
		arr
	  end
	end
	logger.warn "steph: #{@my_bookmarks.inspect}"
  end
end
