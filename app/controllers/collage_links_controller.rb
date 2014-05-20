class CollageLinksController < BaseController
  protect_from_forgery :except => [:create]

  def embedded_pager
    super Collage, 'shared/collage_link_item'
  end

  def create
    @collage_link = CollageLink.new(collage_links_params)
    respond_to do |format|
      if @collage_link.save
        format.json { render :json => @collage_link.to_json }
      else
        format.json { render :text => "We couldn't add that collage link" }
      end
    end
  end

  private
  def collage_links_params
    params.require(:collage_link).permit(:collage_link, :linked_collage_id, :host_collage_id, :link_text_start, :link_text_end)
  end
end
