require 'net/http'
require 'uri'

class PlaylistsController < BaseController
  protect_from_forgery except: [:export, :export_all, :export_as, :position_update, :private_notes, :public_notes, :destroy, :copy, :toggle_nested_private, :submit_import]

  cache_sweeper :playlist_sweeper
  caches_page :show, :export, :export_all, :if => Proc.new { |c| c.instance_variable_get('@playlist').try(:public?) }

  layout 'casebooks', only: [:new, :edit]
  before_action :find_casebook, only: [:edit]

  def casebook_class

  end

  def embedded_pager
    super Playlist
  end

  def access_level
    if current_user
      can_edit = can? :edit, @playlist
      playlist_items = PlaylistItem.unscoped.where(playlist_id: @playlist.id)
      nested_private_count_owned = 0
      nested_private_count_nonowned = 0
      if can_edit
        nested_private_resources = @playlist.nested_private_resources
        nested_private_count_owned = nested_private_resources.select { |i| i.user_id == @playlist.user_id }.size
        nested_private_count_nonowned = nested_private_resources.size - nested_private_count_owned
      end
      render :json => {
        :can_edit                       => can_edit,
        :can_destroy                    => can?(:destroy, @playlist),
        :notes                          => can_edit ? playlist_items.to_json(:only => [:id, :notes, :public_notes]) : [].to_json,
        :custom_block                   => 'playlist_afterload',
        :nested_private_count_owned     => nested_private_count_owned,
        :nested_private_count_nonowned  => nested_private_count_nonowned,
        :is_superadmin                  => current_user.has_role?(:superadmin)
      }
    else
      render :json => {
        :can_edit             => false,
        :can_destroy          => false,
        :notes                => [],
        :custom_block         => 'playlist_afterload',
        :is_superadmin        => false
      }
    end
  end

  def index
    common_index Playlist
  end

  def empty
    sql = "select p.* from playlists p left join playlist_items pi ON p.id = pi.playlist_id where pi.id is null order by p.id desc"
    @playlists = Playlist.find_by_sql(sql)

    respond_to do |format|
      format.csv { send_data(csv_convert(@playlists)) }
      format.html do
        @playlists = @playlists.paginate(:page => params[:page], :per_page => 75)
      end
    end

  end

  def show
    return if redirect_bad_format

    nested_ps = Playlist.includes(:playlist_items).where(id: @playlist.all_actual_object_ids[:Playlist])
    @nested_playlists = nested_ps.inject({}) { |h, p| h["Playlist-#{p.id}"] = p; h }

    @page_cache = true if @playlist.public?
    @editability_path = access_level_playlist_path(@playlist)
    @author_playlists = @playlist.user.playlists.paginate(:page => 1, :per_page => 5)
  end

  def new
    @book = Playlist.where(user: current_user).where(["created_at = updated_at"])
      .first_or_create name: 'Untitled casebook', user: current_user, public: false
    redirect_to edit_book_path @book
  end

  def edit
    if @playlist.nil? || @playlist.user.nil?
      redirect_to root_url
      return
    end
  end

  def create
    return :json => {} if !params.has_key?(:playlist)

    @playlist = Playlist.new(playlist_params)
    @playlist.user = current_user
    verify_captcha(@playlist)

    if @playlist.save
      #IMPORTANT: This reindexes the item with author set
      @playlist.index!

      render :json => { :type => 'playlists', :id => @playlist.id, :name => @playlist.name }
    else
      render :json => { :type => 'playlists', :id => @playlist.id, :error => true, :message => "Could not create playlist, with errors: #{@playlist.errors.full_messages.join(',')}" }
    end
  end

  def update
    if @playlist.update_attributes(playlist_params)
      render :json => { :type => 'playlists', :id => @playlist.id }
    else
      render :json => { :type => 'playlists', :id => @playlist.id, :error => true, :message => "#{@playlist.errors.full_messages.join(', ')}" }
    end
  end

  def destroy
    @playlist.destroy

    render :json => { :success => true, :id => params[:id].to_i }
  rescue Exception => e
    render :json => { :success => false, :error => "Could not delete #{e.inspect}" }
  end

  def copy
    @playlist_pusher = PlaylistPusher.new(:playlist_id => params[:id],
                                          :user_ids => [current_user.id],
                                          :email_receiver => 'destination',
                                          :playlist_name_override => params[:playlist][:name],
                                          :public_private_override => params[:playlist][:public])
    @playlist_pusher.push!

    render :json => { :custom_block => "playlist_clone_response" }
  end

  def position_update
    updates = {}
    ids = []
    params["changed"].each do |k, v|
      updates["pi_#{v["id"]}"] = { :position => v["position"], :playlist_id => v["playlist_id"] }
      ids << v["id"]
    end

    mod_playlists = []
    PlaylistItem.unscoped.includes(:playlist).where(id: ids).each do |playlist_item|
      mod_playlists << playlist_item.playlist_id
      updates["pi_#{playlist_item.id}"][:position] = updates["pi_#{playlist_item.id}"][:position].to_i + playlist_item.playlist.counter_start
      playlist_item.update_columns(updates["pi_#{playlist_item.id}"])
    end

    mod_playlists.uniq.each do |playlist_id|
      Playlist.clear_nonsiblings(playlist_id)
    end

    render :json => {}
  end

  def export
    @item = @playlist  #trans
    all_actual_object_ids = @playlist.all_actual_object_ids
    @preloaded_collages = prepare_collage_export(all_actual_object_ids[:Collage])
    @preloaded_cases = prepare_case_export(all_actual_object_ids[:Case])

    @load_all = params[:load_all]
    if !@load_all
      #load arbitrary number of items to give the user some idea of how things look
      #set to nil to not set any limit
      @playlist_items_limit = 15
    end
    @playlist_items_count = 0

    render :layout => 'print'
  end

  def public_notes
    update_notes(true, @playlist)
  end

  def private_notes
    update_notes(false, @playlist)
  end

  def update_notes(value, playlist)
    playlist.playlist_items.each { |pi| pi.update_column(:public_notes, value) }
    ActionController::Base.expire_page "/playlists/#{playlist.id}.html"
    ActionController::Base.expire_page "/playlists/#{playlist.id}/export.html"

    render :json => {  :total_count => playlist.playlist_items.count,
                       :public_count => playlist.public_count,
                       :private_count => playlist.private_count
                     }
  end

  def playlist_lookup
    render :json => { :items => @current_user.playlists.collect { |p| { :display => p.name, :id => p.id } } }
  end

  def toggle_nested_private
    @playlist.toggle_nested_private

    render :json => { :updated_count => @playlist.nested_private_resources.count }
  end

  private

  def find_casebook
    @book = Playlist.find params[:id]
  end

  def csv_convert(playlists)
    headers = ['Playlist URL', 'Playlist ID', 'Owner', 'Title', 'Description']

    CSV.generate(headers: true) do |csv|
      csv << headers

      playlists.each do |playlist|
        csv << [
          view_context.playlist_url(playlist),
          playlist.id,
          playlist.user.email_address,
          playlist.name,
          playlist.description,
        ]
      end
    end
  end

  def prepare_collage_export(item_ids)
    return {} if item_ids.nil?

    items = Collage.includes(:annotatable, :color_mappings, :annotations => [:layers, :taggings => :tag]).where(id: item_ids)
    items.inject({}) {|mem, item| mem["collage#{item.id}"] = item; mem }
  end

  def prepare_case_export(item_ids)
    return {} if item_ids.nil?

    items = Case.includes(:case_citations, :case_docket_numbers).where(id: item_ids)
    items.inject({}) {|mem, item| mem["case#{item.id}"] = item; mem }
  end

  def playlist_params
    params.require(:playlist).permit(:name, :public, :primary, :tag_list, :description, :counter_start, :featured)
  end
end
