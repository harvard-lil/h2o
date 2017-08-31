class UsersController < ApplicationController
  cache_sweeper :user_sweeper
  protect_from_forgery :except => [:disconnect_dropbox]
  layout 'main', only: [:new, :create, :show, :edit, :update]

  DEFAULT_SHOW_TYPES = {
    :pending_cases => {
      :display => false,
      :header => "Pending Cases",
      :partial => "pending_case"
    },
    :case_requests => {
      :display => false,
      :header => "Case Requests",
      :partial => "case_request"
    },
    :user_responses => {
      :display => false,
      :header => "User Responses",
      :partial => "response"
    }
  }

  def new
    @user = User.new params.fetch(:user, {}).permit(:email_address, :attribution)
  end

  def index
    redirect_to search_path(type: 'users')
    # common_index User
  end

  def verify
    if current_user.present? && current_user == User.where(id: params[:id]).first && params[:token] == current_user.perishable_token
      current_user.update_column(:verified, true)
      flash[:notice] = 'Thank you. Your account has been verified. You may now contribute to H2O.'
      redirect_to user_path(current_user)
      return
    end
    if current_user
      flash[:notice] = 'Your account has not been verified. Please try again by requesting an email verification <a href="' + verification_request_user_url(current_user)  + '" target="blank">here</a>.'
      redirect_to user_path(current_user)
    else
      flash[:notice] = 'Your account has not been verified. Please login and try visiting the link in the email again.'
      redirect_to '/user_sessions/new'
    end
  end

  def create
    @user = User.new(permitted_user_params)

    if @user.save
      @user.send_verification_request
      flash[:success] = I18n.t('users.sign-up.flash.success.html').html_safe
      redirect_to user_path(@user)
    else
      render :action => :new
    end
  end

  def request_anon
    @user = User.new
  end

  def show
    @user = User.find_by_id(params[:id])
    if !@user
      redirect_to :root and return
    end
    render 'content/dashboard'
  end

  def edit
    if current_user
      @user = current_user
    end
  end

  def update
    @user = @current_user

    user_params = permitted_user_params
    if user_params[:password].present? && !@user.valid_password?(user_params[:current_password])
      flash[:error] = "Current password is incorrect."
      return render :edit
    end
    user_params.delete :current_password

    if @user.update_attributes(user_params)
      flash[:success] = 'Profile updated.'
      redirect_to edit_user_path(@user)
    else
      render :edit
    end
  end

  def delete_bookmark_item
    if current_user.bookmark_id.nil?
      render :json => { :success => false, :message => "Error." }
      return
    end

    # playlist_item_to_delete = PlaylistItem.where(playlist_id: current_user.bookmark_id, actual_object_type: params[:type].classify, actual_object_id: params[:id].to_i).first
    if playlist_item_to_delete && playlist_item_to_delete.destroy
      render :json => { :success => true }
    else
      render :json => { :success => false }
    end
  end

  def bookmark_item
    # playlist = current_user.bookmark_id.present? ? Playlist.where(id: current_user.bookmark_id).first : nil
    if playlist.nil?
      # playlist = Playlist.new({ :name => "Your Bookmarks", :public => false, :user_id => current_user.id })
    end

    begin
      if true
        render :json => { :already_bookmarked => true, :user_id => current_user.id }
      else
        render :json => { :already_bookmarked => false, :user_id => current_user.id }
      end
    rescue Exception => e
      logger.warn "#{e.inspect}"
      render :status => 500, :json => {}
    end
  end

  def user_lookup
    @users = User.where("(email_address = ? OR login = ?) AND id != ?", params[:lookup], params[:lookup], current_user.id).collect { |u| { :display => "#{u.login} (#{u.email_address})", :id => u.id } }
    render :json => { :items => @users }
  end

  def playlists
    render :json => { :playlists => User.where(id: params[:id]).first.playlists.select { |p| p.name != 'Your Bookmarks' }.to_json(:only => [:id, :name]) }
  end

  def disconnect_dropbox
    @user = @current_user
    File.delete(@user.dropbox_access_token_file_path)
    render :json => {}
  end

  private
  def permitted_user_params
    permitted_fields = [:id, :name, :login, :password, :password_confirmation,
                                  :current_password, :image,
                                 :email_address, :tz_name, :attribution, :title,
                                 :url, :affiliation, :description, :terms]
    if Rails.configuration.disable_verification
      permitted_fields.push :verified
    end
    params.fetch(:user, {}).permit(*permitted_fields)
  end

  def default_show_types_method
    {
      :pending_cases => {
        :display => false,
        :header => "Pending Cases",
        :partial => "pending_case"
      },
      :case_requests => {
        :display => false,
        :header => "Case Requests",
        :partial => "case_request"
      },
      :user_responses => {
        :display => false,
        :header => "User Responses",
        :partial => "response"
      }
    }
  end

  def build_user_page_content(params)
    @types = DEFAULT_SHOW_TYPES.dup
    # logger.warn "DEFAULT_SHOW_TYPES @types: #{@types}"
    # logger.warn "DEFAULT_SHOW_TYPES current_user: '#{current_user}'"
    # logger.warn "DEFAULT_SHOW_TYPES @user: '#{@user}'"

    #Reset @types to avoid the bug I suspect is lurking in production-only
    @types = default_show_types_method

    if current_user && @user == current_user
      # logger.warn "DEFAULT_SHOW_TYPES: option A"
      @page_title = "Dashboard | H2O Classroom Tools"
      @paginated_bookmarks = @user.bookmarks.paginate(:page => params[:page], :per_page => 10)

      @types[:pending_cases][:display] = true
      @types[:user_responses][:display] = true

      if @user.has_role?(:case_admin)
        @types[:case_requests][:display] = true
      end
    else
      # logger.warn "DEFAULT_SHOW_TYPES: option B"
      @page_title = "User #{@user.simple_display} | H2O Classroom Tools"
    end

    @types.each do |type, v|
      next if !v[:display]

      sorter = Proc.new {|j|
        (j.respond_to?(params[:sort]) ? j.send(params[:sort]) : j.send(:display_name)).to_s.downcase
      }
      if type == :case_requests
        content = CaseRequest.all.sort_by(&sorter)
      else
        content = @user.send(type).sort_by(&sorter)
      end

      if(params[:order] == 'desc')
        content.reverse!
      end

      v[:results] = content.paginate(:page => params[:page], :per_page => 10)
    end
  end

end
