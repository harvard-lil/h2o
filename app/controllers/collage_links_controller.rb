class CollageLinksController < BaseController

  def embedded_pager
    @link_start = params[:link_start]
    @link_end   = params[:link_end]
    @host_collage = params[:collage_id]
    super Collage
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
