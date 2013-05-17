class AnnotationsController < BaseController

  cache_sweeper :annotation_sweeper

  before_filter :require_user, :except => [:show, :embedded_pager, :choose]
  before_filter :load_single_resource, :only => [:show, :edit, :update, :destroy, :metadata]

  access_control do
    allow all, :to => [:show, :metadata, :embedded_pager, :choose]
    allow :superadmin, :admin, :collages_admin

    allow logged_in, :to => [:destroy, :edit, :update, :autocomplete_layers], :if => :allow_edit?
    allow logged_in, :to => [:create, :new]
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update, :create, :new, :autocomplete_layers]
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
    @editors = @annotation.editors
    @original_creators = @annotation.accepted_roles.find(:all, :conditions => {:name => "original_creator"})
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

  # POST /annotations
  # POST /annotations.xml
  def create
    filter_layer_list

    @annotation = Annotation.new(params[:annotation])

    if params.has_key?(:new_layer_list) && (params[:new_layer_list].first[:hex] == "" || params[:new_layer_list].first[:layer] == "")
      render :text => "Please enter a layer name and select a hex.", :status => :unprocessable_entity
      return
    end

    if @annotation.save
      @annotation.accepts_role!(:owner, current_user)
      @annotation.accepts_role!(:editor, current_user)
      @annotation.accepts_role!(:creator, current_user)

      create_color_mappings

      color_map = {}
      @annotation.collage.layers.each do |layer|
        map = @annotation.collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
        color_map[layer.id] = map.hex if map
      end

      render :json => { :annotation => @annotation.to_json(:include => [:layers]), :color_map => color_map.to_json, :type => "create" }
    else
      render :text => "We couldn't add that annotation. Sorry!<br/>#{@annotation.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity
    end
  end

  # PUT /annotations/1
  # PUT /annotations/1.xml
  def update
    filter_layer_list

    current_layers = @annotation.layers

    @annotation.attributes = params[:annotation]
    if @annotation.save
      @annotation.accepts_role!(:editor,current_user)

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

    render :text => "We've deleted that item."
  rescue Exception => e
    logger.warn("Could not delete annotation: #{e.inspect}")
    render :text => "There seems to have been a problem deleting that item. #{e.inspect}", :status => :unprocessable_entity
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

  def create_color_mappings
    if params.has_key?(:new_layer_list)
      params[:new_layer_list].each do |new_layer|
        tag = @annotation.layers.detect { |l| l.name == new_layer["layer"] }
        ColorMapping.create(:collage_id => @annotation.collage_id, :tag_id => tag.id, :hex => new_layer["hex"])
      end
    end
  end
end
