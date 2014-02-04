class AnnotationsController < BaseController

  cache_sweeper :annotation_sweeper

  before_filter :require_user, :except => [:show, :embedded_pager, :choose]
  before_filter :load_single_resource, :only => [:show, :edit, :update, :destroy, :metadata]

  access_control do
    allow all, :to => [:show, :metadata, :embedded_pager, :choose]
    allow :superadmin

    allow logged_in, :to => [:destroy, :edit, :update, :autocomplete_layers], :if => :allow_edit?
    allow logged_in, :to => [:create, :new]

    allow logged_in, :to => [:destroy, :edit, :update, :create, :new, :autocomplete_layers], :if => :is_owner?
  end

  def allow_edit?
    load_single_resource

    current_user.can_permission_collage("edit_annotations", @collage)
  end

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

  def autocomplete_layers
    render :json => Annotation.autocomplete_for(:layers,params[:tag])
  end

  # GET /annotations/1
  # GET /annotations/1.xml
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

  # GET /annotations/new
  # GET /annotations/new.xml
  def new
    @annotation = Annotation.new(:collage_id => params[:collage_id])
    
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

  # GET /annotations/1/edit
  def edit
    @color_map = {}
    @annotation.collage.layers.each do |layer|
      map = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
      @color_map[layer.name] = map.hex if map
    end
  end

  def create
    if !params.has_key?(:annotation)
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
        :linked_collage_id => params[:linked_collage_id]
      }
      filter_layer_list_v2
    else
      filter_layer_list
    end

    @annotation = Annotation.new(params[:annotation])
    @annotation.user = current_user
   
    if params.has_key?(:new_layer_list) && params[:new_layer_list].any? && (params[:new_layer_list].first[:hex] == "" || params[:new_layer_list].first[:layer] == "")
      render :text => "Please enter a layer name and select a hex.", :status => :unprocessable_entity
      return
    end

    if @annotation.save
      create_color_mappings

      color_map = {}
      @annotation.collage.layers.each do |layer|
        map = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
        color_map[layer.id] = map.hex if map
      end

      render :json => { :id => @annotation.id,
                        :annotation => @annotation.to_json(:include => [:layers]), 
                        :color_map => color_map.to_json, :type => "create",
                        :linked_collage_name => @annotation.linked_collage_id.present? ? @annotation.linked_collage.name : nil }
    else
      render :text => "We couldn't add that annotation. Sorry!<br/>#{@annotation.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity
    end
  end

  def update
    if @annotation.collage.annotator_version == 2
      range = params[:ranges].first
      params[:annotation] = {
        :annotation => params[:text] 
      }
      filter_layer_list_v2
    else
      filter_layer_list
    end

    current_layers = @annotation.layers

    @annotation.attributes = params[:annotation]
    if @annotation.save
      #Destroys color mappings for deleted layers that are deletable
      @annotation.reload
      updated_layers = @annotation.layers
      current_layers.each do |layer|
        if !updated_layers.include?(layer) && !@annotation.collage.layers.include?(layer)
          to_delete = @collage.color_mappings.detect { |cm| cm.tag_id == layer.id } 
          ColorMapping.destroy(to_delete) if to_delete
        end
      end

      create_color_mappings

      color_map = {}
      @annotation.collage.layers.each do |layer|
        map = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
        color_map[layer.id] = map.hex if map
      end

      render :json => { :annotation => @annotation.to_json(:include => [:layers]), :color_map => color_map.to_json, :type => "update" }
    else
      render :text => "We couldn't update that annotation. Sorry!<br/>#{@annotation.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity
    end
  end

  # DELETE /annotations/1
  # DELETE /annotations/1.xml
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

  def filter_layer_list
    layer_list = []
    if params.has_key?(:new_layer_list)
      params[:new_layer_list].each do |new_layer|
        new_layer["layer"].downcase!
      end
      layer_list << params[:new_layer_list].map { |c| c["layer"] }
    end
    if params.has_key?(:existing_layer_list)
      layer_list << params[:existing_layer_list]
    end
    params[:annotation][:layer_list] = layer_list.join(', ')
  end

  def filter_layer_list_v2
    layer_list = []
    if params.has_key?(:category)
      params[:category].each do |layer|
        layer_list << layer.gsub(/^layer-/, '').downcase
      end
    end
    if params.has_key?(:new_layer_list)
      params[:new_layer_list].each do |new_layer|
        new_layer["layer"].downcase!
      end
      layer_list << params[:new_layer_list].map { |c| c["layer"] }
    end

    params[:annotation][:layer_list] = layer_list.join(', ')
  end

  def create_color_mappings
    if params.has_key?(:new_layer_list)
      params[:new_layer_list].each do |new_layer|
        tag = @annotation.layers.detect { |l| l.name == new_layer["layer"] }
        ColorMapping.create(:collage_id => @annotation.collage_id, :tag_id => tag.id, :hex => new_layer["hex"])
      end
    end
  end
end
