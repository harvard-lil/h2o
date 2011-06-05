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
