class DropboxSessionsController < ApplicationController
  before_filter :require_user

  def create
    if not params[:oauth_token] then
        dbsession = DropboxSession.new(DROPBOXCONFIG[:app_key], DROPBOXCONFIG[:app_secret])

        session[:dropbox_session] = dbsession.serialize
        redirect_to dbsession.get_authorize_url url_for(:action => 'create')
    else
        # the user has returned from Dropbox
        dbsession = DropboxSession.deserialize(session[:dropbox_session])
        dbsession.get_access_token  #we've been authorized, so now request an access_token
        session[:dropbox_session] = dbsession.serialize
        current_user.save_dropbox_access_token(dbsession.serialize)
        redirect_to :controller => :bulk_uploads, :action => :new
    end
  end
end
