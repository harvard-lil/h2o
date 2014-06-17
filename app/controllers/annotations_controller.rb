class AnnotationsController < BaseController
  cache_sweeper :annotation_sweeper
  protect_from_forgery :except => [:create, :destroy, :update]

  def embedded_pager
    super Annotation
  end

  def metadata
    @annotation[:object_type] = @annotation.class.to_s
    @annotation[:child_object_name] = 'annotation'
    @annotation[:child_object_plural] = 'annotations'
    @annotation[:child_object_count] = nil
    @annotation[:child_object_type] = 'Annotation'
    @annotation[:child_object_ids] = nil
    @annotation[:title] = @annotation.display_name
    render :xml => @annotation.to_xml(:skip_types => true)
  end

  def show
    @color_map = {}
    @annotation.collage.layers.each do |layer|
      map = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
      @color_map[layer.name] = map.hex if map
    end

    @required_layer = @annotation.collage.layers.detect { |l| l.name.downcase == "required" }
    @other_layers = @required_layer.present? ? @annotation.collage.layers.select { |t| t.id != @required_layer.id } : @annotation.collage.layers
    @color_list = Collage.color_list
  end

  def new
    @annotation.collage_id = params[:collage_id]
    
    @color_map = {}
    @annotation.collage.layers.each do |layer|
      map = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
      @color_map[layer.name] = map.hex if map
    end

    @required_layer = @annotation.collage.layers.detect { |l| l.name.downcase == "required" }
    @other_layers = @required_layer.present? ? @annotation.collage.layers.select { |t| t.id != @required_layer.id } : @annotation.collage.layers
    @color_list = Collage.color_list

    [:annotation_start, :annotation_end].each do |p|
      @annotation[p] = params[p]
    end
    [:collage_id].each do |p|
      @annotation[p] = (params[p] == 'null') ? nil : params[p]
    end
  end

  def edit
    @color_map = {}
    @annotation.collage.layers.each do |layer|
      map = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
      @color_map[layer.name] = map.hex if map
    end
  end

  def create
    if params[:layer_hexes].present?
      params[:layer_hexes].each do |k|
        k["layer"].downcase!
      end
    end

    range = params[:ranges].first
    params[:annotation] = {
      :annotation_start => 0,
      :annotation_end => 0,
      :collage_id => params[:collage_id],
      :xpath_start => range[:start],
      :xpath_end => range[:end],
      :start_offset => range[:startOffset],
      :end_offset => range[:endOffset],
      :annotation => params[:text],
      :linked_collage_id => params[:linked_collage_id].present? ? params[:linked_collage_id] : nil,
      :layer_list => params[:layer_hexes].present? ? params[:layer_hexes].collect { |l| l["layer"] }.join(', ') : nil
    }

    @annotation = Annotation.new(annotations_params)
    @annotation.user = current_user
 
    if @annotation.save
      create_color_mappings if params[:layer_hexes].present?

      render :json => { :id => @annotation.id,
                        :layers => @annotation.layers.collect { |l| l.name }.to_json,
                        :text => @annotation.annotation,
                        :linked_collage_id => @annotation.linked_collage_id.present? ? @annotation.linked_collage_id : nil, 
                        :linked_collage_name => @annotation.linked_collage_id.present? ? @annotation.linked_collage.name : nil }
    else
      render :json => { :message => "We couldn't add that annotation. Sorry!<br/>#{@annotation.errors.full_messages.join('<br/>')}" }, 
             :status => :unprocessable_entity
    end
  end

  def update
    params[:annotation] = {
      :annotation => params[:text],
      :linked_collage_id => params[:linked_collage_id].present? ? params[:linked_collage_id] : nil,
      :layer_list => params[:layer_hexes].present? ? params[:layer_hexes].collect { |l| l["layer"] }.join(', ') : nil
    }

    current_layers = @annotation.layers

    if @annotation.update_attributes(annotations_params)

      #Destroys color mappings for deleted layers that are deletable
      @annotation.reload
      updated_layers = @annotation.layers
      current_layers.each do |layer|
        if !updated_layers.include?(layer) && !@annotation.collage.layers.include?(layer)
          to_delete = @collage.color_mappings.detect { |cm| cm.tag_id == layer.id } 
          ColorMapping.destroy(to_delete) if to_delete
        end
      end

      create_color_mappings if params[:layer_hexes].present?
      render :json => { :id => @annotation.id,
                        :layers => @annotation.layers.collect { |l| l.name }.to_json,
                        :linked_collage_id => @annotation.linked_collage_id.present? ? @annotation.linked_collage_id : nil, 
                        :linked_collage_name => @annotation.linked_collage_id.present? ? @annotation.linked_collage.name : nil }
    else
      render :json => { :message => "We couldn't add that annotation. Sorry!<br/>#{@annotation.errors.full_messages.join('<br/>')}" }, 
             :status => :unprocessable_entity
    end
  end

  def destroy
    deleteable_tags = @annotation.collage.deleteable_tags
    @annotation.layers.each do |layer|
      if deleteable_tags.include?(layer.id)
        to_delete = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id } 
        ColorMapping.destroy(to_delete) if to_delete
      end
    end
    @annotation.destroy

    render :json => {}
  rescue Exception => e
    logger.warn("Could not delete annotation: #{e.inspect}")
    render :json => { :error => "There seems to have been a problem deleting that item. #{e.inspect}" }, :status => :unprocessable_entity
  end

  private

  def create_color_mappings
    params[:layer_hexes].each do |layer|
      next if !layer["is_new"]
      tag = @annotation.layers.detect { |l| l.name == layer["layer"] }
      c = ColorMapping.create(collage_id: @annotation.collage_id, tag_id: tag.id, hex: layer[:hex])
    end
  end

  private
  def annotations_params
    params.require(:annotation).permit(:collage_id, :linked_collage_id, :annotation_start, :annotation_end, :xpath_end,
                                       :xpath_start, :start_offset, :end_offset, :annotation, :id, :layer_list)
  end
end
