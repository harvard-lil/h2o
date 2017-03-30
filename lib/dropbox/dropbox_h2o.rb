class DropboxH2o
  def self.logger
    Rails.logger
  end

  def initialize(dropbox_session)
    new_session = DropboxSession.deserialize(dropbox_session)
    @client = DropboxClient.new(new_session, DROPBOXCONFIG[:access_type])
  end

  def self.do_import(klass, dbsession, bulk_upload, user)
    logger.debug "dropbox_h2o.rb (17): do_import message received with KLASS:#{klass.inspect}, DBSESSION: #{dbsession.inspect} BULK_UPLOAD: #{bulk_upload.inspect} USER: #{user.inspect}"
    @dh2o = DropboxH2o.new(dbsession)
    logger.debug "dropbox_h2o.rb (19): new DropboxH2o created"
    begin
      logger.debug "dropbox_h2o.rb (21): begin statement entered"
      @dh2o.import(klass, bulk_upload)
    rescue Exception => e
      logger.error "dropbox_h2o.rb (24): EXCEPTION RAISED: #{e.message}"
    end
    logger.debug "dropbox_h2o.rb (26): import finished"
    Notifier.bulk_upload_completed(user, bulk_upload).deliver
    logger.debug "dropbox_h2o.rb (28): notifier email sent"
  end

  def copy_to_dir(dir, file_path)
    @client.file_copy(file_path, "#{dir}#{file_path}")
  end

  def file_paths
    @file_paths ||= @client.metadata('/')['contents'].map{|entry| entry['path']}
  end

  def get_file(file_path)
    @client.get_file(file_path)
  end

  def write_error(path, error_messages)
    del =DropboxErrorLog.new(@client)
    del.write(path, error_messages)
  end

  def importer
    @importer = DropboxImporter.new(self) unless defined?(@importer)
    @importer
  end

  def respond_to_missing?(method_name, include_private=false); importer.respond_to?(method_name, include_private); end if RUBY_VERSION >= "1.9"
  def respond_to?(method_name, include_private=false); importer.respond_to?(method_name, include_private) || super; end if RUBY_VERSION < "1.9"

  private

  def method_missing(method_name, *args, &block)
    return super unless importer.respond_to?(method_name)
    importer.send(method_name, *args, &block)
  end

end
