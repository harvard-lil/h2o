class CollageLinksController < BaseController
  cache_sweeper :collage_link_sweeper
  def embedded_pager
    params[:page] ||= 1

    if params[:keywords]
      @objects = Sunspot.new_search(Collage)
      @objects.build do
        keywords params[:keywords]
        paginate :page => params[:page], :per_page => 5 || nil

        with :public, true
        with :active, true

        order_by :score, :desc
      end
      @objects.execute!
    else
      @objects = Rails.cache.fetch("collages-embedded-search-#{params[:page]}--karma-asc") do
        obj = Sunspot.new_search(Collage)
        obj.build do
          paginate :page => params[:page], :per_page => 5 || nil

          order_by :karma, :desc
        end
        obj.execute!
        obj
      end
    end

    render :partial => 'shared/collage_link_item', :object => Collage
  end

  def create
    @collage_link = CollageLink.new(params[:collage_link])
    respond_to do |format|
      if @collage_link.save
        format.json { render :json => @collage_link.to_json }
      else
        format.json { render :text => "We couldn't add that collage link" }
      end
    end
  end
end
