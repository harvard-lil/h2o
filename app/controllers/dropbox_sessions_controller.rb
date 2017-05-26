class DropboxSessionsController < BaseController
  def create
    if not params[:oauth_token] then
      dbsession = DropboxSession.new(DROPBOXCONFIG[:app_key], DROPBOXCONFIG[:app_secret])

      session[:dropbox_session] = dbsession.serialize
      redirect_to dbsession.get_authorize_url url_for(:action => 'create')
    else
      # the user has returned from Dropbox
      if params[:serialized_dropbox_session]
        session[:dropbox_session] = params[:serialized_dropbox_session]
      end
      dbsession = DropboxSession.deserialize(session[:dropbox_session])
      dbsession.get_access_token  #we've been authorized, so now request an access_token
      session[:dropbox_session] = dbsession.serialize
      redirect_to :controller => :bulk_uploads, :action => :new
    end
  end
end
