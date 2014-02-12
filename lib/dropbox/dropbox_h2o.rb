class DropboxH2o

  def initialize(dropbox_session)
    new_session = DropboxSession.deserialize(dropbox_session)
    @client = DropboxClient.new(new_session, DROPBOXCONFIG[:access_type])
  end

  #def self.test
    #Notifier.deliver_bulk_upload_completed(User.find(415), BulkUpload.create!)
    #f = File.read('/Users/timcase/Sites/h2o/dbsession.txt')
    #@dh2o = DropboxH2o.new(f)
    #@dh2o.import(Case, BulkUpload.create!)
    #Notifier.deliver_password_reset_instructions(User.find(415))
  #end

  def self.do_import(klass, dbsession, bulk_upload, user)
    puts "dropbox_h2o.rb (17): do_import message received with KLASS:#{klass.inspect}, DBSESSION: #{dbsession.inspect} BULK_UPLOAD: #{bulk_upload.inspect} USER: #{user.inspect}\n"
    @dh2o = DropboxH2o.new(dbsession)
    puts "dropbox_h2o.rb (19): new DropboxH2o created\n"
    begin
      puts "dropbox_h2o.rb (21): begin statement entered\n"
      @dh2o.import(klass, bulk_upload)
    rescue Exception => e
      puts "dropbox_h2o.rb (24): EXCEPTION RAISED: #{e.message}\n"
    end
    puts "dropbox_h2o.rb (26): import finished\n"
    Notifier.deliver_bulk_upload_completed(user, bulk_upload)
    puts "dropbox_h2o.rb (28): notifier email sent\n"
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
