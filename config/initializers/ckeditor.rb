# Use this hook to configure ckeditor
Ckeditor.setup do |config|
  # ==> ORM configuration
  # Load and configure the ORM. Supports :active_record (default), :mongo_mapper and
  # :mongoid (bson_ext recommended) by default. Other ORMs may be
  # available as additional gems.
  require "ckeditor/orm/active_record"

  # Allowed image file types for upload.
  config.image_file_types = ["jpg", "jpeg", "png", "gif"]

  # Allowed attachment file types for upload.
  # Set to nil or [] (empty array) for all file types
  # By default: %w(doc docx xls odt ods pdf rar zip tar tar.gz swf)
  config.attachment_file_types = %w(doc docx xls odt ods pdf)
  
  # Setup authorization to be run as a before filter
  # By default: there is no authorization.
  config.authorize_with do
    current_user_session = UserSession.find
    if current_user_session && current_user_session.record.has_role?(:superadmin)
      # Hooray, pass
    else
      redirect_to "/"
    end
  end

  # Asset model classes
  # config.picture_model { Ckeditor::Picture }
  # config.attachment_file_model { Ckeditor::AttachmentFile }

  # Paginate assets
  # By default: 24
  # config.default_per_page = 24

  # To reduce the asset precompilation time, you can limit plugins and/or languages to those you need:
  # By default: nil (no limit)
  config.assets_languages = ['en']
  #config.assets_plugins = ['image', 'smiley']
end
