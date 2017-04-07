class BulkUploadsController < ApplicationController
  before_action :require_dropbox_session
  before_action :initialize_dropbox_client, :only => [:new, :show]

  def show
  end

  def new
    @files_to_import = @dh2o.import_file_paths
  end

  def create
    bulk_upload = BulkUpload.create!(:user_id => current_user.id)
    BulkUploadJob.perform_later(:dropbox_session => current_dropbox_session,
                                        :user_id => current_user.id,
                                        :bulk_upload_id => bulk_upload.id)
    flash[:notice] = "Download started. You will receive an email when it's finished.  You can also refresh this page to check progress."
    redirect_to bulk_upload_path(bulk_upload)
  end

  def require_dropbox_session
    unless current_dropbox_session
      redirect_to dropbox_sessions_path
      false
    end
  end

  def initialize_dropbox_client
    begin
      @dh2o = ::Dropbox::H2o.new(current_dropbox_session)
    rescue DropboxAuthError
      redirect_to dropbox_sessions_path
    end
  end

  def current_dropbox_session
    session[:dropbox_session]
  end
end
