class CollagesController < BaseController
  cache_sweeper :collage_sweeper

  before_filter :limit_missing_item, :only => :destroy
  
  protect_from_forgery :except => [:export_unique, :save_readable_state, :upgrade_annotator, :copy, :destroy, :collage_list]

  def embedded_pager
    if params.has_key?(:for_annotation)
      super Collage, 'shared/collage_link_item'
    else
      super Collage
    end
  end

  def delete_inherited_annotations
    annotations_to_delete = @collage.annotations.select { |a| a.cloned == true }
    Annotation.destroy(annotations_to_delete)

    render :json => {
      :deleted => annotations_to_delete.to_json(:only => [:id])
    }
  end

  def access_level 
    if current_user && params[:iframe].blank?
      render :json => {
        :can_edit             => can?(:edit, @collage),
        :report_options       => { report: [@collage.enable_feedback, @collage.enable_discussions, @collage.enable_responses].any?, feedback: @collage.enable_feedback, discuss: @collage.enable_discussions, respond: @collage.enable_responses },
        :can_destroy          => can?(:destroy, @collage),
        :responses            => can?(:edit, @collage) ? @collage.responses.to_json(:only => [:created_at, :content, :user_id]) :
                                   current_user.responses.select { |r| r.resource == @collage }.to_json(:only => [:created_at, :content]),
        :custom_block         => "collage_afterload"
      }
    else
      render :json => {
        :can_edit             => false,
        :report_options       => { report: false, feedback: false, discuss: false, respond: false },
        :readable_state       => @collage.readable_state || { :edit_mode => false }.to_json,
        :responses            => [].to_json,
        :custom_block         => params[:iframe].present? ? "collage_afterload" : "collage_v2_afterload"
      }
    end
  end

  def copy
    redirect_to root_url if request.get?

    collage_copy = @collage.h2o_clone(current_user, params[:collage])
    verify_captcha(collage_copy)

    if collage_copy.save
      render :json => { :type => 'collages', :id => collage_copy.id }
    else
      render :json => { :error => true, :message => "#{collage_copy.errors.full_messages.join(',')}" }
    end
  rescue Exception => e
    render :json => { :error => true, :message => "Could not process. Please try again." }, :status => :unprocessable_entity
  end

  def index
    common_index Collage
  end

  def show
    @page_cache = true if @collage.present? && @collage.public?
    @editability_path = access_level_collage_path(@collage)

    @layer_data = @collage.layer_data
  end

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

  def edit
    if @collage.metadatum.blank?
      @collage.build_metadatum
    end
  end

  def create
    @collage = Collage.new(collages_params)
    @collage.user = current_user
    verify_captcha(@collage)
    
    @collage.version = @collage.annotatable.is_a?(Case) ? 1.0 : @collage.annotatable.version

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
    @collage.update_columns({ :readable_state => params[:readable_state], :words_shown => params[:words_shown] })
    render :json => { :time => Time.now.to_s(:simpledatetime) }
  end

  def export
    @item = @collage  #trans
    render :layout => 'print'
  end

  def export_unique
    render :action => 'export', :layout => 'print'
  end

  def export_as
    result = PlaylistExporter.export_as(
      request_url: request.url,
      params: params,
      session_cookie: cookies[:_h2o_session],
      )
      if result.success?
        send_file(result.content_path, filename: result.suggested_filename)
      else
        logger.debug "Export failed: #{result.error_message}"
        render :text => result.error_message
      end
  end


  def collage_lookup
    render :json => { :items => @current_user.collages.collect { |p| { :display => p.name, :id => p.id } } }
  end

  private
  def collages_params
    params.require(:collage).permit(:name, :public, :tag_list, :description, :annotatable_type, :annotatable_id, :featured,
                                    :enable_feedback, :enable_discussions, :enable_responses)
  end
end
