class UsersController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]
  
  def new
    @user = User.new
  end
  
  def create
    @user = User.new(params[:user])
    
    @user.save do |result|
      if result
        flash[:notice] = "Account registered!"
        redirect_back_or_default account_url
      else
        render :action => :new
      end
    end

  end

  def create_anon
    password = ActiveSupport::SecureRandom.random_bytes(10)
    @user = User.new(:login => "anon_#{ActiveSupport::SecureRandom.hex(13)}",
      :password => password,
      :password_confirmation => password)
    @user.has_role! :nonauthenticated
    @user.save do |result|
      if result
        if request.xhr?
          #text doesn't matter, it's the return code that does
          render :text => (session[:return_to] || '/')
        else
          flash[:notice] = "Account registered!"
          redirect_back_or_default account_url
        end
      else
        render :action => :create_anon, :status => :unprocessable_entity
      end
    end
  end
  
  def show
    @user = @current_user
  end

  def edit
    @user = @current_user
  end

  def has_voted_for
    votes = current_user.votes.find(:all, :conditions => ['voteable_type = ?',params[:id]]).collect{|v|v.voteable_id}
    hash = {}
    votes.each{|v| hash[v] = true}
    render :json => hash
  rescue Exception => e
    render :json => {}
  end
  
  def update
    @user = @current_user # makes our views "cleaner" and more consistent
    if @user.update_attributes(params[:user])
      flash[:notice] = "Account updated!"
      redirect_to account_url
    else
      render :action => :edit
    end
  end
end
