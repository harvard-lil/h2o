class CollagesController < BaseController
  cache_sweeper :collage_sweeper
  
  protect_from_forgery :except => [:export_unique, :save_readable_state, :upgrade_annotator, :copy, :destroy]
  caches_page :show, :if => Proc.new{|c| c.instance_variable_get('@collage').present? && c.instance_variable_get('@collage').public?}

  def embedded_pager
    super Collage
  end

  def delete_inherited_annotations
    annotations_to_delete = @collage.annotations.select { |a| a.cloned == true }
    Annotation.destroy(annotations_to_delete)

    render :json => {
      :deleted => annotations_to_delete.to_json(:only => [:id])
    }
  end

  def access_level 
    if current_user
      can_edit = @collage.can_edit?
      can_edit_description = can_edit || current_user.can_permission_collage("edit_collage", @collage)
      can_edit_annotations = can_edit || current_user.can_permission_collage("edit_annotations", @collage)

      render :json => {
        :can_edit             => can_edit,
        :can_edit_description => can_edit_description,
        :can_edit_annotations => can_edit_annotations,
        :custom_block         => "collage_afterload"
      }
    else
      render :json => {
        :can_edit             => false,
        :can_edit_description => false,
        :can_edit_annotations => false,
        :readable_state       => @collage.readable_state || { :edit_mode => false }.to_json,
        :custom_block         => "collage_v2_afterload"
      }
    end
  end

  def heatmap
    render :json => { :heatmap => @collage.heatmap }
  end

  # TODO: Remove this if unused?
  def layers
    render :json => @collage.layers
  end

  def copy
    # FIXME: captcha failing on remix
    #@tmp_collage = Collage.new
    #verify_captcha(@tmp_collage)
    #if !@tmp_collage.valid_recaptcha
    #  render :json => { :error => true, :message => "Captcha failed. Please try again." }
    #  return
    #end

    @collage_copy = @collage.fork_it(current_user, params[:collage])
    if @collage_copy.id.nil?
      render :json => { :error => true, :message => "#{@collage_copy.errors.full_messages.join(',')}" }
      return
    end

    render :json => { :type => 'collages', :id => @collage_copy.id }
  rescue Exception => e
    render :json => { :error => true, :message => "Could not process. Please try again." }, :status => :unprocessable_entity
  end

  def index
    common_index Collage
  end

  def show
    if @collage.nil?
      redirect_to root_url, :status => 301
      return
    end

    @page_cache = true if @collage.present? && @collage.public?
    @editability_path = access_level_collage_path(@collage)

    @color_map = @collage.color_map
  end

  # GET /collages/new
  def new
    klass = params[:annotatable_type].to_s.classify.constantize
    @collage.annotatable_type = params[:annotatable_type]
    @collage.annotatable_id = params[:annotatable_id]
    if klass == Case
      annotatable = klass.where(:id => params[:annotatable_id]).first
      @collage.name = annotatable.short_name
      @collage.tag_list = annotatable.tags.select { |t| t.name }.join(', ')
    end
    if klass == TextBlock
      annotatable = klass.where(:id => params[:annotatable_id]).first
      @collage.name = annotatable.name
      @collage.tag_list = annotatable.tags.select { |t| t.name }.join(', ')
    end
  end

  # GET /collages/1/edit
  def edit
    if @collage.metadatum.blank?
      @collage.build_metadatum
    end
  end

  # POST /collages
  def create
    @collage = Collage.new(collages_params)
    @collage.user = current_user
    verify_captcha(@collage)

    if @collage.save
      render :json => { :type => 'collages', :id => @collage.id, :error => false }
    else
      render :json => { :error => true, :message => "We could not collage this item: #{@collage.errors.full_messages.join('<br />')}" }
    end
  end

  def update
    if @collage.update_attributes(collages_params)
      render :json => { :type => 'collages', :id => @collage.id }
    else
      render :json => { :type => 'collages', :id => @collage.id }
    end
  end

  def destroy
    if @collage.present?
      @collage.destroy
    end

    render :json => {}
  end

  def save_readable_state
    #TODO: Figure out why this is making so many DB calls for optimization
    Collage.update(params[:id], :readable_state => params[:readable_state], :words_shown => params[:words_shown])
    render :json => { :time => Time.now.to_s(:simpledatetime) }
  end

  def export
    render :layout => 'print'
  end

  def export_unique
    render :action => 'export', :layout => 'print'
  end

  def collage_lookup
    render :json => { :items => @current_user.collages.collect { |p| { :display => p.name, :id => p.id } } }
  end

  private
  def collages_params
    params.require(:collage).permit(:name, :public, :tag_list, :description, :annotatable_type, :annotatable_id)
  end
end
