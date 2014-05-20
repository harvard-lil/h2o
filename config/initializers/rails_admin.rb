RailsAdmin.config do |config|
  ## == Devise ==
  # config.authenticate_with do
  #   warden.authenticate! scope: :user
  # end
  #config.current_user_method(&:current_user)

  ## == Cancan ==
  config.authorize_with do
    redirect_to "/" if current_user.nil? || !current_user.has_role?(:superadmin)
  end

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app
  end

  config.included_models = ['Playlist', 'Collage', 'Case', 'User', 'TextBlock', 'Media', 'Default']
end
