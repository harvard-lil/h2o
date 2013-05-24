class BulkUploadsController < ApplicationController
  before_filter :require_user
  before_filter :require_dropbox_session
  before_filter :initialize_dropbox_client
  before_filter :add_assets, :only => [:show, :new]
  
  def show
    @bulk_upload = BulkUpload.find(params[:id])
  end
  
  def new    
    @files_to_import = @dh2o.import_file_paths
  end
  
  def create
    bulk_upload = @dh2o.import(Case) 
    redirect_to bulk_upload_path(bulk_upload)   
  end
  
  def require_dropbox_session
    unless current_dropbox_session
      redirect_to(:controller => 'dropbox_sessions', :action => 'create') 
      false
    end
  end
  
  def current_dropbox_session
    session[:dropbox_session]
  end
  
  def initialize_dropbox_client
    @dh2o = DropboxH2o.new(session[:dropbox_session])
  end
  
  def add_assets
    add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor', 'cases']
    add_stylesheets ['new_case']    
  end
end