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

    if !request.xhr? || params[:is_ajax] == 'playlists'
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

    if !request.xhr? || params[:is_ajax] == 'collages'
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

    if !request.xhr? || params[:is_ajax] == 'cases'
	  @cases = Sunspot.new_search(Case)
	  @cases.build do
	    if params.has_key?(:keywords)
	      keywords params[:keywords]
	    end
	    with :public, true
	    with :active, true
	    paginate :page => params[:page], :per_page => cookies[:per_page] || nil

	    # FIGURE OUT IF THE FOLLOWING LINE IS NEEDED
	    #data_accessor_for(Case).include = {:tags => [], :collages => ...

	    order_by params[:sort].to_sym, :asc
	  end
      @cases.execute!
	end

	if current_user
      @is_case_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','case_admin','superadmin']}).length > 0
	  @is_collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
	  @my_collages = current_user.collages
	  @my_playlists = current_user.playlists
	  @my_cases = current_user.cases
	else
	  @is_collage_admin = @is_case_admin = false
	  @my_collages = @my_playlists = @my_cases = []
	end

    playlist_admin_preload

	respond_to do |format|
	  format.html do
	    if request.xhr?
		  render :partial => "#{params[:is_ajax]}/#{params[:is_ajax]}_block"
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
	    if p.resource_item_type == type && p.resource_item.actual_object
		  arr << p.resource_item.actual_object
		end
		arr
	  end
	end
  end
end
