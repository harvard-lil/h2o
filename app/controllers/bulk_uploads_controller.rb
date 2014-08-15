class BulkUploadsController < ApplicationController
  before_filter :require_dropbox_session
  before_filter :initialize_dropbox_client, :only => [:new, :show]

  def show
  end

  def new
    @files_to_import = @dh2o.import_file_paths
  end

  def create
    bulk_upload = BulkUpload.create!(:user_id => current_user.id)
    BulkUploadsWorker.delay.send_import(:dropbox_session => current_dropbox_session,
                                        :user_id => current_user.id,
                                        :bulk_upload_id => bulk_upload.id)
    flash[:notice] = "Download started. You will receive an email when it's finished.  You can also refresh this page to check progress."
    redirect_to bulk_upload_path(bulk_upload)
  end

  def require_dropbox_session
    try_to_load_access_token
    unless current_dropbox_session
      redirect_to_dropbox_sessions
      false
    end
  end

  def try_to_load_access_token
    return if current_dropbox_session
    session[:dropbox_session] = current_user.dropbox_access_token
  end

  def initialize_dropbox_client
    begin
      @dh2o = DropboxH2o.new(current_dropbox_session)
    rescue DropboxAuthError
      redirect_to_dropbox_sessions
    end
  end

  def redirect_to_dropbox_sessions
    redirect_to dropbox_sessions_path
  end

  def current_dropbox_session
    session[:dropbox_session]
  end
end
